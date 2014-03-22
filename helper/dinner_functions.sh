#!/bin/bash
##################################################
#
# vim: ai:ts=4:sw=4:noet:sts=4:ft=sh
#
# Copyright 2013, Steven Koeberich (nemesissre@gmail.com)
#
# Title:			Dinner
# Author:			Steven "NemesisRE" Koeberich
# Author URL:		https://nrecom.net
# Source URL:		https://github.com/NemesisRE/dinner
# Contributors:		ToeiRei
# Creation Date:	20131117
# Version:			2.0
# Description:		Builds Roms automatically
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at (http://www.gnu.org/licenses/) for
# more details.


function _dinner_update () {
	_e_pending "Checking for updates"
	eval "cd ${DINNER_DIR}"
	eval "$(which git) pull --no-stat --no-progress 2>${DINNER_TEMP_DIR}/dinner_update.err >${DINNER_TEMP_DIR}/dinner_update.log"
	if [ "${?}" == "0" ]; then
		if [ "$($(which cat) ${DINNER_TEMP_DIR}/dinner_update.log)" != "Already up-to-date." ]; then
			_e_pending_success "Successfully updated"
		else
			_e_pending_success "Already up-to-date."
		fi
	else
		_e_pending_error "while Dinner update, see details below:\n"
		while read -r LINE; do
			printf "${BLDRED}%11b\t%b${TXTDEF}" " " "${LINE}\n"
		done < ${DINNER_TEMP_DIR}/dinner_update.err
	fi
}

function _generate_local_manifest () {
	if [ "${#LOCAL_MANIFEST[@]}" != 0 ]; then
		local CURRENT_LOCAL_MANIFEST=${REPO_DIR}/.repo/local_manifests/dinner_${CURRENT_CONFIG}.xml
		_e_pending "Generating Local Manifest..."
		printf "%s\n" '<?xml version="1.0" encoding="UTF-8"?>' > ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.xml
		printf "%s\n" '<manifest>' >> ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.xml
		for LINE in "${LOCAL_MANIFEST[@]}"; do
			printf "\t%s\n" "${LINE}" >> ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.xml
		done
		printf "%s\n" '</manifest>' >> ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.xml
		if [ ! -e ${CURRENT_LOCAL_MANIFEST} ] || [ "$(${MD5_BIN} ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.xml | awk '{ print $1 }')" != "$($MD5_BIN ${CURRENT_LOCAL_MANIFEST} | awk '{ print $1 }')" ]; then
			_exec_command "mv ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.xml ${CURRENT_LOCAL_MANIFEST}"
			FORCE_SYNC=true
			_e_pending_success "Successfully generated local manifest."
		else
			_e_pending_skipped "Local manifest is current, no changes needed."
		fi
	fi
}

function _add_device_config () {
	[[ ${1} ]] && local DEVICE_CONFIG_NAME=${1}
	if [ -f ${DEVICE_CONFIG_NAME} ]; then
		_e_pending "Adding config..."
		if [ "$(sed -n '1{p;q;}' ${DEVICE_CONFIG_NAME})" = "${DINNER_CONFIG_HEADER}" ]; then
			[[ "$(sed -n '2{p;q;}' ${DEVICE_CONFIG_NAME})" != "${DINNER_CONFIG_VERSION}" ]] && _e_pending_fatal "Config version differs from current version" "Version of ${DEVICE_CONFIG_NAME}: $(sed -n '2{p;q;}' ${DEVICE_CONFIG_NAME} | awk -F_ '{print $3}')" "Current version: $(echo ${DINNER_CONFIG_VERSION} | awk -F_ '{print $3}')"
			if [ -e ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME} ] && $(diff ${DEVICE_CONFIG_NAME} ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME} >/dev/null); then
				unset ANSWER
				_e_pending_warn "Config with the same name already existing"
				_e_pending "Do you want to overwrite it? (y/N): "  "ACTION" "${BLDWHT}" "0"
				read -n1 ANSWER
				if ! [[ "${ANSWER}" =~ [yY] ]]; then
					_e_pending_skipped "Will not overwrite existing config"
					continue
				fi
			fi
			until [[ "${UVY}" =~ [yY] ]]; do
				unset UVY USERVALUE
				_e "\n${BLDYLW}" "REPO_DIR" "Path to repository (e.g. \"${HOME}/android/omni\")"
				_e_pending " " "VALUE" "${BLDWHT}" "0"
				read USERVALUE
				_e_pending "Is REPO_DIR=\"${USERVALUE}\" correct? (y/N): " "ANSWER" "${BLDBLU}" "0"
				read -n1 UVY
			done
			[[ ${USERVALUE} ]] && _exec_command "$(which sed) -i \"s!^REPO_DIR=\(\\\"\|\'\).*\(\\\"\|\'\)\(.*\)!REPO_DIR=\\\"${USERVALUE}\\\"\\\3!g\" ${DEVICE_CONFIG_NAME}" "_e_pending_fatal \"There was an error while adding config.\""
			_exec_command "cp ${DEVICE_CONFIG_NAME} ${DINNER_CONF_DIR}/" "_e_pending_error \"There was an error while adding config.\"" "_e_pending_success \"Successfully added config.\""
			printf "${BLDWHT}%s${TXTDEF}\n" "Available Configs:" && _print_configs "\t\t%s\n"
		else
			_e_pending_error "${DEVICE_CONFIG_NAME} is not a valid dinner config."
		fi
	else
		if [ -e ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME} ]; then
			unset ANSWER
			_e_warn "Config with the same name already existing"
			_e_pending "Do you want to overwrite it? (y/N): "  "ACTION" "${BLDWHT}" "0"
			read -n1 ANSWER
			if ! [[ "${ANSWER}" =~ [yY] ]]; then
				_e_pending_skipped "Will not overwrite existing config"
				continue
			fi
			_e_pending_notice "Creating basic config ${DEVICE_CONFIG_NAME}"
		else
			_e_notice "Creating basic config ${DEVICE_CONFIG_NAME}"
		fi
		printf "${DINNER_CONFIG_HEADER}\n" > ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME}
		printf "${DINNER_CONFIG_VERSION}\n" >> ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME}
		old_IFS=$IFS
		IFS=$'\n'
		printf "${BLDWHT}%$((HALIGN+1))s\t%s${TXTDEF}\n" " " "Lets define the basic variables."
		for LINE in $($(which cat) ${DINNER_CONF_DIR}/example.dist | sed 's/^#//g' | sed '/^#/ d' ); do
			unset UVY
			VARIABLE="$(echo ${LINE} | awk -F= '{ print $1 }')"
			VARIABLE_DESC="$(echo ${LINE} | awk -F% '{ print $2 }')"
			until [[ "${UVY}" =~ [yY] ]]; do
				_e "${BLDYLW}" "${VARIABLE}" "${VARIABLE_DESC:-No Description available}"
				_e_pending " " "VALUE" "${BLDWHT}" "0"
				read USERVALUE
				_e_pending "Is ${VARIABLE}=\"${USERVALUE}\" correct? (y/N): " "ANSWER" "${BLDBLU}" "0"
				read -n1 UVY
				echo " "
			done
			[[ ${USERVALUE} ]] && printf "%s\t\t\t\t\t%s\n" "${VARIABLE}=\"${USERVALUE}\"" "#% ${VARIABLE_DESC:-No Description available}" >> ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME}
		done
		IFS=$old_IFS
		$(which cat) ${DINNER_CONF_DIR}/example.dist | sed -e "1,/${VARIABLE}/d" >> ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME}
		_e_success "Succesfully created config \"${DEVICE_CONFIG_NAME}\""
		_e_notice "If you want to add additional configuration values, such as defining a local manifest use:" "\"dinner config edit ${DEVICE_CONFIG_NAME}\""
	fi
}

function _del_device_config () {
	[[ ${1} ]] && local DEVICE_CONFIG_NAME=${1}
	if [ -e ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME} ]; then
		unset ANSWER
		_e_pending "Are you sure you want to remove config \"${DEVICE_CONFIG_NAME}\"? (y/N): "  "ACTION" "${BLYLW}" "0"
		read -n1 ANSWER
		if ! [[ "${ANSWER}" =~ [yY] ]]; then
			_e_pending_skipped "Did not remove config \"${DEVICE_CONFIG_NAME}\""
		else
			_exec_command "rm -v ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME}"
			_e_pending_success "Successfully removed config \"${DEVICE_CONFIG_NAME}\""
		fi
	else
		_e_warn "Config \"${DEVICE_CONFIG_NAME}\" does not exist."
	fi
}

function _show_device_config () {
	[[ ${1} ]] && local DEVICE_CONFIG_NAME=${1}
	if [ -f ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME} ]; then
		head -2 "${DINNER_CONF_DIR}/${params}"
		$(which cat) "${DINNER_CONF_DIR}/${params}" | sed -e '/^#/ d' | awk -F# '{ print $1 }'| sed '/^\s*$/d' | sed 's/[ \t]*$//'
	else
		_e_error "Can not show config ${DEVICE_CONFIG_NAME}, config does not exist!"
	fi
}

function _check_prerequisites () {
	unset REPOPICK LOCAL_MANIFEST CHERRYPICK
	eval CURRENT_LOG="${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log"
	eval CURRENT_ERRLOG="${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}_error.log"
	printf "${DINNER_LOG_COMMENT}\nThis Combined Log contains messages from STDOUT and STDERR\n\n" &> ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log}
	printf "${DINNER_LOG_COMMENT}\nThis Error Log contains only messages from STDERR\n\n" &> ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log}

	_e_notice "Starting work on config \"${CURRENT_CONFIG}\"..."

	if [ -f "${DINNER_DIR}/config.d/${CURRENT_CONFIG}" ]; then
		if [ "$(sed -n '1{p;q;}' ${DINNER_DIR}/config.d/${CURRENT_CONFIG})" != "${DINNER_CONFIG_HEADER}" ] ; then
			_e_fatal "${CURRENT_CONFIG} is not a valid dinner config." $EX_CONFIG
		elif [ "$(sed -n '2{p;q;}' ${DINNER_DIR}/config.d/${CURRENT_CONFIG})" != "${DINNER_CONFIG_VERSION}" ]; then
			_e_warn "Config version differs from current version" "Version of ${DEVICE_CONFIG_NAME}: $(sed -n '2{p;q;}' ${DINNER_DIR}/config.d/${CURRENT_CONFIG} | awk -F_ '{print $3}')" "Current version: $(echo ${DINNER_CONFIG_VERSION} | awk -F_ '{print $3}')"
		fi
		_exec_command "source ${DINNER_DIR}/config.d/${CURRENT_CONFIG}"
	else
		_e_fatal "Config \"${CURRENT_CONFIG}\" not found!"
	fi

	if [[ $(which javac) ]] && [[ $(which java) ]]; then
		JAVAC_VERSION=$($(which javac) -version 2>&1 | awk '{print $2}')
		JAVA_VERSION=$($(which java) -version 2>&1 | awk -F '"' '/version/ {print $2}')
		if [[ "${JAVAC_VERSION:0:3}" != "${DINNER_USE_JAVA}" || "${JAVA_VERSION:0:3}" > "${DINNER_USE_JAVA}" ]]; then
			_e_fatal "Your java and/or javac version is not ${DINNER_USE_JAVA}!"
		fi
	else
		_e_fatal "Could not find Java"
	fi

	_check_variables

	if [ ! -d ${REPO_DIR}/.repo ]; then
		if [ ! -d ${REPO_DIR} ]; then
			_exec_command "mkdir -p ${REPO_DIR}" "_e_fatal \"Could not create repo directory (${REPO_DIR})\""
		fi
		if [ -d ${REPO_DIR} ] && [ ${REPO_BRANCH} ] && [ ${REPO_URL} ]; then
			_exec_command "cd ${REPO_DIR}"
			_e_notice "Init repo \"${REPO_URL}\" at \"${REPO_DIR}\""
			_exec_command "${REPO_BIN} init -u ${REPO_URL} -b ${REPO_BRANCH}" "_e_pending_fatal \"Something went wrong  while initiating repo\""
			_e_pending "Running initial repo sync, this will take a while (go get some coffee)..."
			_exec_command "${REPO_BIN} sync ${SYNC_PARAMS} -f --no-clone-bundle" "_e_pending_fatal \"Something went wrong  while doing repo sync\"" "_e_pending_success \"Successfully synced repo\""
		else
			_e_fatal "${REPO_DIR} is not a Repo and REPO_URL/REPO_BRANCH not given can't init repo."
		fi
	fi

	_source_envsetup

	if [ ${DINNER_CCACHE_SIZE} ] && [ -z ${DINNER_CCACHE_SIZE##*[!0-9]*} ]; then
		_exec_command "${REPO_DIR}/prebuilts/misc/linux-x86/ccache/ccache -M ${DINNER_CCACHE_SIZE}" "_e_warn \"There was an error while setting ccache size, take a look into the logs.\""
	fi

	if [ -x ${REPO_DIR}/vendor/cm/get-prebuilts ]; then
		_exec_command "${REPO_DIR}/vendor/cm/get-prebuilts"
	fi

	_set_current_variables

	_exec_command "cd \"${REPO_DIR}\""

	_e_pending "Breakfast ${CURRENT_DEVICE}"
	_exec_command "breakfast ${CURRENT_DEVICE}"
	if [ ${?} != 0 ]; then
		_exec_command "${REPO_BIN} sync ${SYNC_PARAMS}"
		if [ ${?} != 0 ]; then
			_e_pending_fatal "Something went wrong while running breakfast for ${CURRENT_DEVICE}"
		else
			_exec_command "breakfast ${CURRENT_DEVICE}" "_e_pending_fatal \"Something went wrong while running breakfast for ${CURRENT_DEVICE}\"" "_e_pending_success \"Successfully run breakfast ${CURRENT_DEVICE}\""
		fi
	else
		_e_pending_success "Successfully run breakfast ${CURRENT_DEVICE}"
	fi
}

function _check_variables () {
	# Check essentials
	if [ ! ${REPO_DIR} ] || [ -z ${REPO_DIR} ]; then
		_e_fatal "REPO_DIR is not set!"
	fi
	if [ ! ${BRUNCH_DEVICE} ] || [ -z ${BRUNCH_DEVICE} ]; then
		_e_fatal "No BRUNCH_DEVICE given!"
	fi
	if [ ! ${REPO_BRANCH} ] || [ -z ${REPO_BRANCH} ]; then
		_e_warn "No REPO_BRANCH given, dinner won't be able to init the repo!"
	fi
	if [ ! ${REPO_URL} ] || [ -z ${REPO_URL} ]; then
		_e_warn "No REPO_URL given, dinner won't be able to init the repo!"
	fi

	if [ ${SKIP_SYNC_TIME} ] && [ -z ${SKIP_SYNC_TIME##*[!0-9]*} ]; then
		_e_warn "SKIP_SYNC_TIME has no valid number, will use default (30)!"
		SKIP_SYNC_TIME="30"
	fi

	[[ ${DINNER_USE_CCACHE} ]] && [[ ${DINNER_USE_CCACHE} =~ ^{0,1}$ ]] && export USE_CCACHE=${DINNER_USE_CCACHE}

	[[ ${DINNER_CCACHE_DIR} ]] && export CCACHE_DIR=${DINNER_CCACHE_DIR}

	if [ ${CLEANUP_OLDER_THAN} ] && [ -z "${CLEANUP_OLDER_THAN##*[!0-9]*}" ]; then
		_e_warn "CLEANUP_OLDER_THAN has no valid number set, won't use it!"
		CLEANUP_OLDER_THAN=""
	fi

	[[ ${TARGET_DIR} ]] && TARGET_DIR=$(echo "${TARGET_DIR}"|sed 's/\/$//g')
}

function _source_envsetup () {
	if [ ! -d "${REPO_DIR}/.repo" ]; then
		_e_fatal "${REPO_DIR} is not a Repo!"
	elif [ -f "${REPO_DIR}/build/envsetup.sh" ]; then
		_exec_command "source ${REPO_DIR}/build/envsetup.sh"
	else
		_e_fatal "${REPO_DIR}/build/envsetup.sh could not be found."
	fi
}

function _set_current_variables () {
	#Set initial exitcodes
	CURRENT_BUILD_SKIPPED=false
	CURRENT_SYNC_REPO_EXIT_CODE=0
	CURRENT_REPOPICK_EXIT_CODE=0
	CURRENT_BUILD_STATUS=false
	CURRENT_CONFIG_EXIT_CODE=0
	CURRENT_BRUNCH_DEVICE_EXIT_CODE=0
	CURRENT_COPY_BUILD_EXIT_CODE=0
	CURRENT_COPY_OTA_BUILD_EXIT_CODE=0
	CURRENT_PRE_BUILD_COMMAND_EXIT_CODE=0
	CURRENT_POST_BUILD_COMMAND_EXIT_CODE=0
	CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=0
	CURRENT_SEND_MAIL_EXIT_CODE=0

	#Set current config Variables
	eval CURRENT_REPO_NAME=$(echo ${REPO_DIR} | sed 's/\//_/g')
	eval CURRENT_LASTSYNC_MEM="${DINNER_MEM_DIR}/${CURRENT_CONFIG}_lastsync.mem"
	eval CURRENT_CHANGELOG="${DINNER_MEM_DIR}/${CURRENT_CONFIG}_changelog.mem"
	eval CURRENT_LASTBUILD_MEM="${DINNER_MEM_DIR}/${CURRENT_CONFIG}_lastbuild.mem"
	eval CURRENT_DEVICE="${BRUNCH_DEVICE}"
	eval CURRENT_PRE_BUILD_COMMAND="${PRE_BUILD_COMMAND}"
	eval CURRENT_POST_BUILD_COMMAND="${POST_BUILD_COMMAND}"
	eval CURRENT_TARGET_DIR="${TARGET_DIR}"
	eval CURRENT_OTA_TARGET_DIR="${OTA_TARGET_DIR}"
	eval CURRENT_CLEANUP_OLDER_THAN="${CLEANUP_OLDER_THAN}"
	eval CURRENT_USER_MAIL="${USER_MAIL}"
	eval CURRENT_ADMIN_MAIL="${ADMIN_MAIL}"
	eval CURRENT_DOWNLOAD_LINK="${DOWNLOAD_LINK}"
	eval CURRENT_STATUS="failed"
	[[ ${CURRENT_CHANGELOG_ONLY} ]] && CURRENT_CHANGELOG_ONLY="true" || CURRENT_CHANGELOG_ONLY="false"
	[[ ${CURRENT_MAKE_ONLY} ]] && CURRENT_MAKE_ONLY="true" || CURRENT_MAKE_ONLY="false"
}

function _sync_repo () {
	_e_pending "repo sync..."
	if ! ${FORCE_SYNC} && ! ${SKIP_SYNC} && [ -f "${CURRENT_LASTSYNC_MEM}" ] && [ $($(which cat) "${CURRENT_LASTSYNC_MEM}") ] && [[ $(($(date +%s) - $($(which cat) "${CURRENT_LASTSYNC_MEM}"))) -lt $((SKIP_SYNC_TIME*60)) ]]; then
		_e_pending_skipped "Skipping repo sync, it was alread synced in the last ${SKIP_SYNC_TIME} minutes."
	else
		if ${FORCE_SYNC} || ! ${SKIP_SYNC}; then
			_exec_command "${REPO_BIN} sync ${SYNC_PARAMS}" "_e_pending_error \"Something went wrong while doing repo sync\"" "_e_pending_success \"Successfully synced repo\""
			CURRENT_SYNC_REPO_EXIT_CODE=$?
			if [ "${CURRENT_SYNC_REPO_EXIT_CODE}" == 0 ]; then
				[[ ${CURRENT_DEVICE} ]] && echo $(date +%s) > "${CURRENT_LASTSYNC_MEM}"
			fi
		else
			_e_pending_skipped "Skipping repo sync..."
		fi
	fi
}

function _repo_pick () {
	if [ "${#REPOPICK[@]}" != "0" ]; then
		if [ -x ${REPO_DIR}/build/tools/repopick.py ]; then
			export ANDROID_BUILD_TOP=${REPO_DIR}
			_e_pending "Picking Gerrit ID(s) you selected..."
			_exec_command "${REPO_DIR}/build/tools/repopick.py ${REPOPICK_PARAMS} $(echo ${REPOPICK[@]})" "_e_pending_error \"Something went wrong while picking change(s):\" ${REPOPICK[@]}" "_e_pending_success \"Successfully picked change(s): \" ${REPOPICK[@]}"
			CURRENT_REPOPICK_EXIT_CODE=${?}
		else
			_e_warn "Could not find repopick.py, cannot make a repopick."
			CURRENT_REPOPICK_EXIT_CODE=1
		fi
	fi
}

function _brunch_device () {
	_e_pending "Brunch for config \"${CURRENT_CONFIG}\" (Device: ${CURRENT_DEVICE})..."
	_exec_command "brunch ${CURRENT_DEVICE}"
	CURRENT_BRUNCH_DEVICE_EXIT_CODE=${?}
	CURRENT_OUTPUT_FILEPATH=$(tail ${CURRENT_LOG} | grep -i "Package complete:" | awk '{print $3}' | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" 2> /dev/null)
	CURRENT_BRUNCH_RUN_TIME=$(tail ${CURRENT_ERRLOG} | grep "real" | awk '{print $2}' | tr -d ' ' 2> /dev/null)
	if [ "${CURRENT_BRUNCH_DEVICE_EXIT_CODE}" == 0 ]; then
		_e_pending_success "Brunch of config ${CURRENT_CONFIG} finished after ${CURRENT_BRUNCH_RUN_TIME}"
		_check_build
		if ${CURRENT_BUILD_STATUS}; then
			CURRENT_STATUS="finished successfully"
			_post_build_command
			_copy_build
			_clean_old_builds
		fi
	else
		unset ANSWER
		_e_pending_error "Brunch of config ${CURRENT_CONFIG} failed after ${CURRENT_BRUNCH_RUN_TIME}"
		if ! ${DINNER_CRON}; then
			_e_pending "Do you want to paste the error log to ${STIKKED_PASTE_URL}? (y/N): " "ACTION" "${BLYLW}" "0"
			read -t 120 -n1 ANSWER
			if [[ "${ANSWER}" =~ [yY] ]]; then
				_paste_log ${CURRENT_ERRLOG}
			else
				_e_pending_error "See logfiles for more information" "Combined Log: ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log}" "Error log: ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log}"
			fi
		fi
	fi
}

function _copy_build () {
	if [ "${CURRENT_TARGET_DIR}" ]; then
		_e_pending "Moving files to target directory..."
		if [ -d "${CURRENT_TARGET_DIR}/" ]; then
			_exec_command "cp -f ${CURRENT_OUTPUT_FILEPATH}* ${CURRENT_TARGET_DIR}/" "_e_pending_error \"Something went wrong while moving the build\"" "_e_pending_success \"Successfully copied build to ${CURRENT_TARGET_DIR}/\""
			CURRENT_COPY_BUILD_EXIT_CODE=$?
		else
			CURRENT_COPY_BUILD_EXIT_CODE=1
			_e_pending_warn "${CURRENT_TARGET_DIR}/ is not a Directory."
		fi
	fi
	if [ "${CURRENT_OTA_TARGET_DIR}" ]; then
		_e_pending "Moving OTA file to target directory..."
		if [ -d "${CURRENT_OTA_TARGET_DIR}/" ]; then
			CURRENT_OUTPUT_PATH=$(dirname ${CURRENT_OUTPUT_FILEPATH})
			CURRENT_OTA_FILE=$(find ${CURRENT_OUTPUT_PATH} -maxdepth 1 -type f \( -name "*${CURRENT_DEVICE}*" -a -name "*ota*" \) -a \( -name "*.zip" -o -name "*.zip.md5sum" \) | tr "\n" " ")
			_exec_command "cp -f ${CURRENT_OTA_FILE} ${CURRENT_OTA_TARGET_DIR}/" "_e_pending_error \"Something went wrong while moving the OTA file\"" "_e_pending_success \"Successfully copied OTA file to ${CURRENT_TARGET_DIR}/\""
			CURRENT_COPY_OTA_BUILD_EXIT_CODE=$?
		else
			CURRENT_COPY_OTA_BUILD_EXIT_CODE=1
			_e_pending_warn "${CURRENT_OTA_TARGET_DIR}/ is not a Directory."
		fi
	fi
}

function _pre_build_command () {
	if [ ${CURRENT_PRE_BUILD_COMMAND} ]; then
		_e_pending "pre build command..."
		_exec_command "${CURRENT_PRE_BUILD_COMMAND}" "_e_warn \"Something went wrong while running your pre build command\"" "_e_success \"Succesfully run pre build command\""
		CURRENT_PRE_BUILD_COMMAND_EXIT_CODE=$?
	fi
}

function _post_build_command () {
	if [ ${CURRENT_POST_BUILD_COMMAND} ]; then
		_e_pending "post build command..."
		_exec_command "${CURRENT_POST_BUILD_COMMAND}" "_e_warn \"Something went wrong while running your post build command\"" "_e_success \"Succesfully run post build command\""
		CURRENT_POST_BUILD_COMMAND_EXIT_CODE=$?
	fi
}


# change it that it always keeps the latest (the actual build will never deleted even if we set CLEANUP_OLDER_THAN=0 because 0=24h)
function _clean_old_builds () {
	if [ "${CURRENT_CLEANUP_OLDER_THAN}" ]; then
		_e_pending "Running cleanup of old builds..."
		if [ "${CURRENT_TARGET_DIR}" ] && [ -d "${CURRENT_TARGET_DIR}" ]; then
			CURRENT_CLEAN_TARGET=$(find ${CURRENT_TARGET_DIR} -maxdepth 1 \( -name "*${CURRENT_DEVICE}*" -a \( -regextype posix-extended -regex '.*\-[0-9]{8}\-.*' -o -name "*ota*" \) -a -name "*${CURRENT_DEVICE}*" -a \( -name "*.zip" -o -name "*.zip.md5sum" \) \) -type f -mtime +${CURRENT_CLEANUP_OLDER_THAN} )
		fi
		CURRENT_OUTPUT_PATH=$(dirname ${CURRENT_OUTPUT_FILEPATH})
		CURRENT_CLEAN_OUT=$(find ${CURRENT_OUTPUT_PATH} -maxdepth 1 \( -name "*${CURRENT_DEVICE}*" -a \( -regextype posix-extended -regex '.*\-[0-9]{8}\-.*' -o -name "*ota*" \) -a -name "*${CURRENT_DEVICE}*" -a \( -name "*.zip" -o -name "*.zip.md5sum" \) \) -type f -mtime +${CURRENT_CLEANUP_OLDER_THAN} )
		if [ ${CURRENT_CLEAN_TARGET} ] && [ ${CURRENT_CLEAN_OUT} ]; then
			CURRENT_CLEANED_FILES="${CURRENT_CLEAN_TARGET} ${CURRENT_CLEAN_OUT}"
		elif [ ${CURRENT_CLEAN_TARGET} ]; then
			CURRENT_CLEANED_FILES="${CURRENT_CLEAN_TARGET}"
		elif [ ${CURRENT_CLEAN_OUT} ]; then
			CURRENT_CLEANED_FILES="${CURRENT_CLEAN_OUT}"
		fi
		if [ "${CURRENT_CLEANED_FILES}" ] && ! [[ "${CURRENT_CLEANED_FILES}" =~ ^[[:space:]]+$ ]]; then
			for OLDFILE in ${CURRENT_CLEANED_FILES}; do
				_exec_command "rm -v ${OLDFILE}"
				CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=$((${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE} + ${?}))
			done
			if [ "${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE}" = 0 ]; then
				_e_pending_success "Cleanup finished, removed the following files:" "${CURRENT_CLEANED_FILES}"
			else
				_e_pending_warn "Something went wrong while cleaning builds for ${CURRENT_CONFIG}."
			fi
		else
			_e_pending_skipped "Cleanup skipped, nothing to do for ${CURRENT_CONFIG}."
		fi
	fi
}

function _check_build () {
	if [ -f "${CURRENT_OUTPUT_FILEPATH}" ]; then
		CURRENT_OUT_FILE_SECONDS_SINCE_CREATION=$(/bin/date -d "now - $( /usr/bin/stat -c "%Y" ${CURRENT_OUTPUT_FILEPATH} 2>/dev/null ) seconds" +%s)
		if [ "${CURRENT_OUT_FILE_SECONDS_SINCE_CREATION}" -lt "120" ] ; then
			CURRENT_BUILD_STATUS=true
		else
			_e_error "Outputfile too old!"
		fi
	else
		_e_error "Outputfile does not exist!"
	fi
}

function _dinner_make {
	if [ ${CURRENT_DINNER_MAKE} ]; then
		CURRENT_BUILD_SKIPPED=true
		_e_pending "make ${CURRENT_DINNER_MAKE}..."
		_exec_command "make ${CURRENT_DINNER_MAKE}" '_e_pending_warn "make ${CURRENT_DINNER_MAKE} has failed"' '_e_pending_success "Successfully run make ${CURRENT_DINNER_MAKE}"'
		if ${CURRENT_MAKE_ONLY}; then
			_check_current_config
		fi
	fi
}

function _check_current_config () {
	CURRENT_CONFIG_EXIT_CODE=$(( \
		${SYNC_REPO_EXIT_CODE} \
		+${CURRENT_REPOPICK_EXIT_CODE}\
		+${CURRENT_BRUNCH_DEVICE_EXIT_CODE} \
		+${CURRENT_COPY_BUILD_EXIT_CODE} \
		+${CURRENT_COPY_OTA_BUILD_EXIT_CODE} \
		+${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE} \
		+${CURRENT_SEND_MAIL_EXIT_CODE} \
	))
	if ${CURRENT_BUILD_SKIPPED}; then
		SUCCESS_CONFIGS="${SUCCESS_CONFIGS}\"${CURRENT_CONFIG}\" "
	elif ${CURRENT_BUILD_STATUS} && [ "${CURRENT_CONFIG_EXIT_CODE}" -eq 0 ]; then
		SUCCESS_CONFIGS="${SUCCESS_CONFIGS}\"${CURRENT_CONFIG}\" "
		NMA_PRIORITY=0
		echo $(date +%m/%d/%Y) > ${CURRENT_LASTBUILD_MEM}
	elif ${CURRENT_BUILD_STATUS} && [ "${CURRENT_CONFIG_EXIT_CODE}" -gt 0 ]; then
		WARNING_CONFIGS="${WARNING_CONFIGS}\"${CURRENT_CONFIG}\" "
		NMA_PRIORITY=1
	elif ! ${CURRENT_BUILD_STATUS} && [ "${CURRENT_CONFIG_EXIT_CODE}" -eq 0 ]; then
		_e_warn "Buildcheck for config \"${CURRENT_CONFIG}\" has failed but overall exit code is fine" "${CURRENT_CONFIG_EXIT_CODE}"
		FAILED_CONFIGS="${FAILED_CONFIGS}\"${CURRENT_CONFIG}\" "
		NMA_PRIORITY=2
	elif ! ${CURRENT_BUILD_STATUS}; then
		FAILED_CONFIGS="${FAILED_CONFIGS}\"${CURRENT_CONFIG}\" "
		NMA_PRIORITY=2
	else
		_e_warn "Could not determine status for config \"${CURRENT_CONFIG}\"" "${CURRENT_CONFIG_EXIT_CODE}"
		NMA_PRIORITY=2
	fi
	DINNER_EXIT_CODE=$((${DINNER_EXIT_CODE}+${CURRENT_CONFIG_EXIT_CODE}))
}

# get changelog needs to be reviewed there is much that can be made better
# it must be easier to maintain the credits...
function _get_changelog () {
	_e_pending "Gathering Changes since last successfull build..."
	if [ -f "${CURRENT_LASTBUILD_MEM}" ] && [ $($(which cat) ${CURRENT_LASTBUILD_MEM}) ]; then
		LASTBUILD=$($(which cat) ${CURRENT_LASTBUILD_MEM})
		[[ -f ${CURRENT_CHANGELOG} ]] && rm ${CURRENT_CHANGELOG}

		find ${REPO_DIR} -name .git | sed 's/\/.git//g' | sed 'N;$!P;$!D;$d' | while read line
		do
			cd $line
			log=$(git log --pretty="%an - %s" --since=${LASTBUILD} --date-order)
			project=$(git remote -v | head -n1 | awk '{print $2}' | sed 's/.*\///' | sed 's/\.git//')
			if [ ! -z "$log" ]; then
				origin=`grep "$project" ${REPO_DIR}/.repo/manifest.xml | awk {'print $4'} | cut -f2 -d '"'`

				case $origin in
					bam)		proj_credit=JELLYBAM;;
					aosp)		proj_credit=AOSP;;
					cm)			proj_credit=CyanogenMod;;
					omnirom)	proj_credit=OmniRom;;
#verify					pac)		proj_credit=PAC-man;;
					*)			proj_credit=NotListed
				esac

				printf '%s' "Project (by $proj_credit): $project" >> ${CURRENT_CHANGELOG}

				echo "$log" | while read line
				do
					printf '\t%s' "$line" >> ${CURRENT_CHANGELOG}
				done

				echo "" >> ${CURRENT_CHANGELOG}
			fi
		done
		if [ -f ${CURRENT_CHANGELOG} ] && [ "$($(which cat) ${CURRENT_CHANGELOG})" ]; then
			sed -i "1i Changes since last build $($(which cat) ${CURRENT_LASTBUILD_MEM})\n=============================" ${CURRENT_CHANGELOG}
		fi
		if ${CURRENT_CHANGELOG_ONLY}; then
			CURRENT_BUILD_SKIPPED=true
			[[ -f ${CURRENT_CHANGELOG} ]] && _e_pending_success "Showing changelog: \n" && $(which cat) ${CURRENT_CHANGELOG} || _e_pending_warn "No Changelog found"
			_check_current_config
		else
			_e_pending_success "Successfully gathered changes."
		fi
	else
		_e_pending_warn "Skipping gathering changes, no successfull build for config \"${CURRENT_CONFIG}\" found."
		if ${CURRENT_CHANGELOG_ONLY}; then
			CURRENT_BUILD_SKIPPED=true
			_e_pending "Searching last changelog..."
			sleep 3
			[[ -f ${CURRENT_CHANGELOG} ]] && _e_pending_success "Showing last changelog: " && $(which cat) ${CURRENT_CHANGELOG} || _e_pending_warn "No Changelog found"
			_check_current_config
		fi
	fi
}

function _cleanup () {
	_log_msg "Running cleanup..."

	_exec_command "rm -vf ${DINNER_TEMP_DIR}/*"

	if [ $(find ${DINNER_LOG_DIR} -name dinner.log -size +20M -type f) ]; then
		mv ${DINNER_LOG_DIR}/dinner.log ${DINNER_LOG_DIR}/remove.log
		tail -100 ${DINNER_LOG_DIR}/remove.log > dinner.log
	fi

	if [ $(find ${DINNER_LOG_DIR} -name dinner_error.log -size +20M -type f) ]; then
		mv ${DINNER_LOG_DIR}/dinner_error.log ${DINNER_LOG_DIR}/remove_error.log
		tail -100 ${DINNER_LOG_DIR}/remove_error.log > dinner_error.log
	fi

	_exec_command "find ${DINNER_MEM_DIR}/ $(_print_configs '! -name \"*%s*\" ') ! -name .empty -type f -exec rm -v {} \;"
	_exec_command "find ${DINNER_LOG_DIR}/ $(_print_configs '! -name \"*%s*\" ') ! -name .empty ! -name dinner_error.log ! -name dinner.log -type f -exec rm -v {} \;"
	if [ ${REPO_DIR} ]; then
		_exec_command "find ${REPO_DIR}/.repo/local_manifests/ -name \"dinner*\" $(_print_configs '! -name \"*%s*\" ') -type f -exec rm -v {} \;"
	fi

	for ENV_VAR in ${BACKUP_ENV[@]}; do
		_exec_command "export ${ENV_VAR}"
	done
}

function _paste_log () {
	[[ ${1} ]] && [[ ${1} =~ ^[0-9]+$ ]] || local PASTE_LOG="$(basename ${1})"
	[[ ${2} ]] && PASTE_LINES="${2}"

	if [ ${PASTE_LOG} ] && [[ ${PASTE_LINES} =~ ^[0-9]+$ ]]; then
		tail -${PASTE_LINES} "${DINNER_LOG_DIR}/${PASTE_LOG}" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" > "${DINNER_TEMP_DIR}/paste.log" 2>/dev/null
	elif [ ${PASTE_LOG} ] && [[ "${PASTE_LINES}" = "full" ]]; then
		$(which cat) "${DINNER_LOG_DIR}/${PASTE_LOG}" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" > "${DINNER_TEMP_DIR}/paste.log" 2>/dev/null
	else
		_e_pending_warn "No log available."
	fi

	if [ -f ${DINNER_TEMP_DIR}/paste.log ]; then
		printf "\n\nJAVAC_VERSION=$($(which javac) -version 2>&1 | awk '{print $2}')\n" >> "${DINNER_TEMP_DIR}/paste.log"
		if [[ ${PASTE_LOG} =~ _error ]]; then
			printf "\n${DINNER_LOG_COMMENT}\nThis Error Log contains only messages from STDERR\n\n" >> "${DINNER_TEMP_DIR}/paste.log"
		else
			printf "${DINNER_LOG_COMMENT}\nThis Combined Log contains messages from STDOUT and STDERR\n\n" >> "${DINNER_TEMP_DIR}/paste.log"
		fi
		CURRENT_PASTE_URL=$(${CURL_BIN} -d title="Dinner Log Paste" -d name=Dinner --data-urlencode text@${DINNER_TEMP_DIR}/paste.log ${STIKKED_PASTE_URL} 2>/dev/null)
		_e_pending_notice "Your Log is here available: ${CURRENT_PASTE_URL}"
	fi
}

function _send_notification () {
	_generate_notification
	_notify_mail
	_notify_nma
	_notify_pb
}

function _generate_user_message () {
	printf "%s\n" "${1}" >> "${DINNER_TEMP_DIR}/user_notification.txt"
}

function _generate_admin_message () {
	printf "%s\n" "${1}" >> "${DINNER_TEMP_DIR}/admin_notification.txt"
}

function _generate_notification () {
	if ${CURRENT_BUILD_STATUS}; then
		_generate_admin_message "Used config \"${CURRENT_CONFIG}\""
		if [ "${CURRENT_DOWNLOAD_LINK}" ]; then
			_generate_user_message "You can download your Build at:\n${CURRENT_DOWNLOAD_LINK}"
			_generate_admin_message "You can download your Build at:\n${CURRENT_DOWNLOAD_LINK}"
			fi

			if [ -f ${CURRENT_CHANGELOG} ] && [ "$($(which cat) ${CURRENT_CHANGELOG})" ]; then
			_generate_user_message "$($(which cat) ${CURRENT_CHANGELOG})"
			_generate_admin_message "$($(which cat) ${CURRENT_CHANGELOG})"
			fi

			if [ "${CURRENT_CLEANED_FILES}" ]; then
			_generate_admin_message "Removed the following files:"
			_generate_admin_message "${CURRENT_CLEANED_FILES}"
		fi
	else
		if [ -f ${CURRENT_LOG} ]; then
			$(which cat) ${CURRENT_LOG} | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" > ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.log
			_exec_command "tar -C ${DINNER_TEMP_DIR} -zchf ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.log.tgz dinner_${CURRENT_CONFIG}.log"
			LOGFILE="-a \"${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.log.tgz\""
		fi
		if [ -f ${CURRENT_ERRLOG} ]; then
			$(which cat) ${CURRENT_ERRLOG} | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" > ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}_error.log
			_exec_command "tar -C ${DINNER_TEMP_DIR} -zchf ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}_error.log.tgz dinner_${CURRENT_CONFIG}_error.log"
			ERRLOGFILE="-a \"${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}_error.log.tgz\""
		fi
	fi
}

function _notify_mail () {
	if [ ${MAIL_BIN} ] && ([ "${CURRENT_USER_MAIL}" ] || [ "${CURRENT_ADMIN_MAIL}" ]); then
		if ${CURRENT_BUILD_STATUS} && [ ${CURRENT_USER_MAIL} ]; then
			_e_pending "Sending User E-Mail..."
			_exec_command "$(which cat) \"${DINNER_TEMP_DIR}/user_notification.txt\" | sed 's/$/<br>/' | ${MAIL_BIN} -e \"set content_type=text/html\" -s \"[Dinner] Build for ${CURRENT_DEVICE} ${CURRENT_STATUS} (${CURRENT_BRUNCH_RUN_TIME})\" \"${CURRENT_USER_MAIL}\"" "_e_pending_error \"Something went wrong while sending User E-Mail\"" "_e_pending_success \"Successfully sent User E-Mail\""
			CURRENT_SEND_MAIL_EXIT_CODE=$?
		fi

		if [ ${CURRENT_ADMIN_MAIL} ]; then
			_e_pending "Sending Admin E-Mail..."
			_exec_command "$(which cat) \"${DINNER_TEMP_DIR}/admin_notification.txt\" | sed 's/$/<br>/' | ${MAIL_BIN} -e \"set content_type=text/html\" -s \"[Dinner] Build for ${CURRENT_DEVICE} ${CURRENT_STATUS} (${CURRENT_BRUNCH_RUN_TIME})\" \"${CURRENT_ADMIN_MAIL}\" ${LOGFILE} ${ERRLOGFILE}" "_e_pending_error \"Something went wrong while sending Admin E-Mail\""  "_e_pending_success \"Successfully sent Admin E-Mail\""
			CURRENT_SEND_MAIL_EXIT_CODE=$(($CURRENT_SEND_MAIL_EXIT_CODE + $?))
		fi
	fi
}

# Inspired by https://github.com/moepi/nomyan
function _notify_nma () {
	if [ ${NMA_APIKEY} ]; then
		# send notifcation
		_e_pending "Sending NMA notification..."
		if ! ${CURRENT_BUILD_STATUS}; then
		_paste_log "${CURRENT_ERRLOG}" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" >> ${DINNER_TEMP_DIR}/admin_notification.txt
		fi
		NMA_DESCRIPTION=$($(which cat) ${DINNER_TEMP_DIR}/mail_admin_message.txt | sed 's/$/<br>/' )
		NMA_RESPONSE=$(${CURL_BIN} -s --data-ascii apikey=${NMA_APIKEY} --data-ascii application="Dinner" --data-ascii event="Build for ${CURRENT_DEVICE} ${CURRENT_STATUS} (${CURRENT_BRUNCH_RUN_TIME})" --data-ascii description="${NMA_DESCRIPTION}" --data-ascii priority=${NMA_PRIORITY} --data-ascii content-type="text/html" ${NMA_APIURL} -o- | sed 's/.*success code="\([0-9]*\)".*/\1/')

		# handle return code
		case ${NMA_RESPONSE} in
			200)
			_e_pending_success "Successfully sent NMA notification to API key ${NMA_APIKEY}."
			;;
			400)
			_e_pending_error "The data supplied is in the wrong format, invalid length or null."
			;;
			401)
			_e_pending_error "API key not valid."
			;;
			402)
			_e_pending_error "Maximum number of API calls per hour exceeded."
			;;
			500)
			_e_pending_error "Internal server error. Please contact NMA support if the problem persists."
			;;
			*)
			_e_pending_error "An unexpected error occured."
			;;
		esac
	fi
}

# Inspired by https://github.com/Red5d/pushbullet-bash
function _notify_pb () {
	if [ ${PB_APIKEY} ]; then
		_e_pending "Sending Pushbullet notification..."
		if ! ${CURRENT_BUILD_STATUS}; then
			_paste_log "${CURRENT_ERRLOG}" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" >> ${DINNER_TEMP_DIR}/admin_notification.txt
		fi

		PB_DESCRIPTION=$($(which cat) ${DINNER_TEMP_DIR}/mail_admin_message.txt | sed 's/$/<br>/' )
		PB_API_DEVICES=$(curl -s "${PB_APIURL}/devices" -u ${PB_APIKEY}: | tr '{' '\n' | tr ',' '\n' | grep model | cut -d'"' -f4)
		PB_API_IDENS=$(curl -s "${PB_APIURL}/devices" -u ${PB_APIKEY}: | tr '{' '\n' | tr ',' '\n' | grep iden | cut -d'"' -f4)

		if [ ${PB_DEVICE} ]; then
			PB_CURRENT_IDEN=$(echo "${PB_API_IDENS}" | sed -n $(echo "${PB_API_DEVICES}" | grep -i -n ${PB_DEVICE} | cut -d: -f1)'p')
			PB_RESPONSE=$(${CURL_BIN} -s "${PB_APIURL}/pushes" -u ${PB_APIKEY}: -d device_iden=${CURRENT_PB_IDEN} -d type=note -d title="Build for ${CURRENT_DEVICE} ${CURRENT_STATUS} (${CURRENT_BRUNCH_RUN_TIME})" -d body="${PB_DESCRIPTION}" -X POST | grep -o "created" | tail -n1)
		else
			for CURRENT_PB_IDEN in ${PB_API_IDENS}; do
				PB_RESPONSE=$(${CURL_BIN} -s "${PB_APIURL}/pushes" -u ${PB_APIKEY}: -d device_iden=${CURRENT_PB_IDEN} -d type=note -d title="Build for ${CURRENT_DEVICE} ${CURRENT_STATUS} (${CURRENT_BRUNCH_RUN_TIME})" -d body="${PB_DESCRIPTION}" -X POST | grep -o "created" | tail -n1)
			done
		fi

		[[ "${PB_RESPONSE}" = "created" ]] && _e_pending_success "Successfully sent PB notification to API key ${PB_APIKEY}." || _e_pending_error "An unexpected error occured, while sending PB notification."
	fi
}

function _clear_logs () {
	[[ ${1} ]] && [[ ${1} =~ ^[0-9]+$ ]] && local OLDER_THAN="! -mtime ${1}" || local OLDER_THAN=""
	[[ ${2} ]] && local CONFIG="${2}" || local CONFIG="*"
	_e_pending "Cleaning logfiles for ${CONFIG}..."
	LOGFILE_RESULT=$(find ${DINNER_LOG_DIR}/ -name "dinner_${CONFIG}_*.log" -type f ${OLDER_THAN} -printf '%p ')
	if [ "${LOGFILE_RESULT}" ]; then
		for RMLOGFILE in ${LOGFILE_RESULT}; do
			_exec_command "rm -v ${RMLOGFILE}"
		done
		_e_pending_success "Successfull cleaned following logs for ${CONFIG}:" ${LOGFILE_RESULT}
	else
		_e_pending_skipped "Skipping cleaning logs for ${CONFIG}, nothing to do"
	fi
}

function _print_configs {
	[[ ${1} ]] && local ARGS="${1}"
	while IFS= read -d $'\0' -r configpath ; do
		local config=$(basename "${configpath}")
		printf "${ARGS:-%b\n}" "$config"
	done < <(find "${DINNER_CONF_DIR}" -mindepth 1 -maxdepth 1 -type f ! -name DINNER_DEFAULTS ! -name *example.dist -print0 | sort -z)
	return $EX_SUCCESS
}

function _run_config () {
	case ${1} in
		"changelog")
			CURRENT_CHANGELOG_ONLY=true
			CURRENT_CONFIG=${2}
			;;
		"make")
			CURRENT_MAKE_ONLY=true
			CURRENT_DINNER_MAKE=${2}
			CURRENT_CONFIG=${3}
			;;
		"build")
			CURRENT_CONFIG=${2}
			;;
		*)
			_e_fatal "Unknown command '$1'" $EX_USAGE
			;;
	esac

	_check_prerequisites

	_dinner_make

	_generate_local_manifest

	_sync_repo

	_repo_pick

	_get_changelog

	_pre_build_command

	_brunch_device

	_check_current_config

	_send_notification
}
