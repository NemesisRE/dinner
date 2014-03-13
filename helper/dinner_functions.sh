#!/bin/bash
##################################################
#
# vim: ai:ts=4:sw=4:noet:sts=4:ft=sh
#

function _dinner_update () {
	_e_pending "Checking for updates"
	eval "cd ${DINNER_DIR}"
	eval "$(which git) pull --no-stat --no-progress 2>${DINNER_TEMP_DIR}/dinner_update.err >${DINNER_TEMP_DIR}/dinner_update.log"
	if [ "${?}" == "0" ]; then
		if [ "$(cat ${DINNER_TEMP_DIR}/dinner_update.log)" != "Already up-to-date." ]; then
			_e_pending_success "Successfully updated"
			_e_notice "Restart your Shell or run: \"source ${DINNER_DIR}/dinner.sh\""
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

function _generate_user_message () {
	echo -e "${1}" >> "${DINNER_TEMP_DIR}/mail_user_message.txt"
}

function _generate_admin_message () {
	echo -e "${1}" >> "${DINNER_TEMP_DIR}/mail_admin_message.txt"
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
			mv ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.xml ${CURRENT_LOCAL_MANIFEST}
			FORCE_SYNC=true
			_e_pending_success "Successfully generated Local Manifest."
		else
			_e_pending_success "Manifest is current, no changes needed."
		fi
	fi
}

function _add_device_config () {
	[[ ${1} ]] && local DEVICE_CONFIG_NAME=${1}
	if [ -f ${DEVICE_CONFIG_NAME} ]; then
		_e_pending "Adding config..."
		if [ "$(head -1 ${DEVICE_CONFIG_NAME})" = "${DINNER_CONFIG_HEADER}" ]; then
			if [ -e ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME} ] && $(diff ${DEVICE_CONFIG_NAME} ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME} >/dev/null); then
				_e_pending_warn "Config with the same name already existing"
				_e_pending "Do you want to overwrite it? (y/N): "  "ACTION" "${BLDWHT}" "0"
				read -n1 ANSWER
				if ! [[ "${ANSWER}" =~ [yY] ]]; then
					_e_pending_skipped "Will not overwrite existing config"
					exit 0
				fi
			fi
			_exec_command "cp ${1} ${DINNER_CONF_DIR}/" "_e_pending_error \"There was an error while adding config.\"" "_e_pending_success \"Successfully added config.\""
			printf "${BLDWHT}%s${TXTDEF}\n" "Available Configs:" && _print_configs "\t\t%s\n"
			exit 0
		else
			_e_pending_error "${DEVICE_CONFIG_NAME} is not a valid dinner config."
			exit 1
		fi
	else
		if [ -e ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME} ] && $(diff ${DEVICE_CONFIG_NAME} ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME} >/dev/null); then
			_e_warn "Config with the same name already existing"
			_e_pending "Do you want to overwrite it? (y/N): "  "ACTION" "${BLDWHT}" "0"
			read -n1 ANSWER
			if ! [[ "${ANSWER}" =~ [yY] ]]; then
				_e_pending_skipped "Will not overwrite existing config"
				exit 0
			fi
			_e_pending_notice "Creating config ${DEVICE_CONFIG_NAME}"
		else
			_e_notice "Creating config ${DEVICE_CONFIG_NAME}"
		fi
		head -5  ${DINNER_CONF_DIR}/example.dist
		printf "DINNER CONFIG FILE (Source: https://github.com/NemesisRE/dinner) developed by NemesisRE (https://nrecom.net)" > ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME}
		for VARIABLE in $(cat ${DINNER_CONF_DIR}/example.dist | sed 's/^#//g' | sed '/^#/ d' | awk -F= '{ print $1 }' ); do
			_e "${BLDWHT} "DESCRIPTION" "${VARIABLE_DESC:-"No Description available"} (Dinnerdefault: ${!VARIABLE:-none})"
			_e_pending " "  "${VARIABLE}" "${BLDWHT}" "0"
			read USERVALUE
			[[ ${USERVALUE} ]] && eval "${VARIABLE}=${USERVALUE}" >> ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME}
		done
		_e_success "Here is your new config (${DEVICE_CONFIG_NAME}):"
		_exec_command "cat ${DINNER_CONF_DIR}/${DEVICE_CONFIG_NAME}"
		exit ${?}
	fi
}

function _check_prerequisites () {
	eval CURRENT_LOG="${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log"
	eval CURRENT_ERRLOG="${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}_error.log"
	printf "${DINNER_LOG_COMMENT}\nThis Combined Log contains messages from STDOUT and STDERR\n\n" &> ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log}
	printf "${DINNER_LOG_COMMENT}\nThis Error Log contains only messages from STDERR\n\n" &> ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log}

	if [ -f "${DINNER_DIR}/config.d/${CURRENT_CONFIG}" ]; then
		if [ "$(head -1 ${DEVICE_CONFIG_NAME})" = "${DINNER_CONFIG_HEADER}"]; then
			_exec_command "source ${DINNER_DIR}/config.d/${CURRENT_CONFIG}"
		else
			_e_fatal "${CURRENT_CONFIG} is not a valid dinner config."
		fi
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

	_source_envsetup

	if [ -x ${REPO_DIR}/vendor/cm/get-prebuilts ]; then
		_exec_command "${REPO_DIR}/vendor/cm/get-prebuilts"
	fi

	_set_current_variables

	_exec_command "cd \"${REPO_DIR}\""

	_e_notice "Starting work on config \"${CURRENT_CONFIG}\"..."
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
	CURRENT_BUILD_STATUS=false
	CURRENT_CONFIG_EXIT_CODE=0
	CURRENT_BRUNCH_DEVICE_EXIT_CODE=0
	CURRENT_MOVE_BUILD_EXIT_CODE=0
	CURRENT_PRE_BUILD_COMMAND_EXIT_CODE=0
	CURRENT_POST_BUILD_COMMAND_EXIT_CODE=0
	CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=0
	CURRENT_SEND_MAIL_EXIT_CODE=0

	#Set current config Variables
	eval CURRENT_REPO_NAME=$(echo ${REPO_DIR} | sed 's/\//_/g')
	eval CURRENT_LASTSYNC_MEM="${DINNER_MEM_DIR}/${CURRENT_CONFIG}_lastsync.mem"
	eval CURRENT_CHANGELOG="${DINNER_MEM_DIR}/${CURRENT_CONFIG}_changelog.mem"
	eval CURRENT_LASTBUILD_MEM="${DINNER_MEM_DIR}/${CURRENT_CONFIG}_lastbuild.mem"
	eval CURRENT_REPOPICK="\"${REPOPICK}\""
	eval CURRENT_DEVICE="${BUILD_FOR_DEVICE}"
	eval CURRENT_PRE_BUILD_COMMAND="${PRE_BUILD_COMMAND}"
	eval CURRENT_POST_BUILD_COMMAND="${POST_BUILD_COMMAND}"
	eval CURRENT_TARGET_DIR="${TARGET_DIR}"
	eval CURRENT_CLEANUP_OLDER_THAN="${CLEANUP_OLDER_THAN}"
	eval CURRENT_MAIL="${USER_MAIL}"
	eval CURRENT_ADMIN_MAIL="${ADMIN_MAIL}"
	eval CURRENT_DOWNLOAD_LINK="${DOWNLOAD_LINK}"
	eval CURRENT_STATUS="failed"
	[[ ${CURRENT_CHANGELOG_ONLY} ]] && CURRENT_CHANGELOG_ONLY="true" || CURRENT_CHANGELOG_ONLY="false"
	[[ ${CURRENT_MAKE_ONLY} ]] && CURRENT_MAKE_ONLY="true" || CURRENT_MAKE_ONLY="false"
}

function _check_variables () {
	# Check essentials
	if [ ! ${REPO_BIN} ] || [ ! -x ${REPO_BIN} ]; then
		_e_fatal "Repo binary (${REPO_BIN}) is not found or not executable!"
	fi

	if [ ! "${REPO_DIR}" ]; then
		_e_fatal "REPO_DIR is not set!"
	elif [ ! ${BUILD_FOR_DEVICE} ]; then
		_e_fatal "No Device given! Stopping..."
	fi

	if [ ${SKIP_SYNC_TIME} ] && [ -z ${SKIP_SYNC_TIME##*[!0-9]*} ]; then
		_e_error "SKIP_SYNC_TIME has no valid number, will use default (1800)!"
		SKIP_SYNC_TIME="1800"
	fi

	[[ ${DINNER_USE_CCACHE} ]] && [[ ${DINNER_USE_CCACHE} =~ ^{0,1}$ ]] && export USE_CCACHE=${DINNER_USE_CCACHE}

	[[ ${DINNER_CCACHE_DIR} ]] && export CCACHE_DIR=${DINNER_CCACHE_DIR}

	if [ ${DINNER_CCACHE_SIZE} ] && [ -z ${DINNER_CCACHE_SIZE##*[!0-9]*} ]; then
		_exec_command "${REPO_DIR}/prebuilts/misc/linux-x86/ccache/ccache -M ${DINNER_CCACHE_SIZE}" "_e_error \"There was an error while setting ccache size, take a look into the logs.\""
	fi

	if [ ${CLEANUP_OLDER_THAN} ] && [ -z "${CLEANUP_OLDER_THAN##*[!0-9]*}" ]; then
		_e_error "CLEANUP_OLDER_THAN has no valid number set, won't use it!"
		CLEANUP_OLDER_THAN=""
	fi

	[[ ${TARGET_DIR} ]] && TARGET_DIR=$(echo "${TARGET_DIR}"|sed 's/\/$//g')
}

function _sync_repo () {
	_e_pending "repo sync..."
	if ! ${FORCE_SYNC:-"false"} && ! ${SKIP_SYNC:-"false"} && [ -f "${CURRENT_LASTSYNC_MEM}" ] && [ $(($(date +%s)-$(cat "${CURRENT_LASTSYNC_MEM}"))) -lt ${SKIP_SYNC_TIME:-"1800"} ]; then
		_e_pending_skipped "Skipping repo sync, it was alread synced in the last ${SKIP_SYNC_TIME:-\"1800\"} seconds."
	else
		if ${FORCE_SYNC:-"false"} || ! ${SKIP_SYNC:-"false"}; then
			_exec_command "${REPO_BIN} sync ${SYNC_PARAMS:-"-q -d -j100"}" "_e_pending_error \"Something went wrong  while doing repo sync\"" "_e_pending_success \"Successfully synced repo\""
			CURRENT_SYNC_REPO_EXIT_CODE=$?
			if [ "${CURRENT_SYNC_REPO_EXIT_CODE}" == 0 ]; then
				echo $(date +%s) > "${CURRENT_LASTSYNC_MEM}"
			fi
		else
			_e_pending_skipped "Skipping repo sync..."
			CURRENT_SYNC_REPO_EXIT_CODE=0
		fi
	fi
}

function _repo_pick () {
	if [ "${#CURRENT_REPOPICK[@]}" ]; then
		if [ -x ${REPO_DIR}/build/tools/repopick.py ]; then
			export ANDROID_BUILD_TOP=${REPO_DIR}
			for CHANGE in ${CURRENT_REPOPICK[@]}; do
				_exec_command "${REPO_DIR}/build/tools/repopick.py ${CHANGE}"
			done
		else
			_e_error "Could not find repopick.py, cannot make a repopick."
		fi
	fi
}

function _get_breakfast_variables () {
	_e_pending "Breakfast and getting its variables..."
	for VARIABLE in $(breakfast ${CURRENT_DEVICE} | sed -e 's/^=.*//' -e 's/[ ^I]*$//' -e '/^$/d' | grep -E '^[A-Z_]+=(.*)' &> >(tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log}) 2> >(tee -a ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log})); do
		eval "${VARIABLE}"
	done

	DINNER_DEVICE_PATH="${REPO_DIR}/device/$(echo $TARGET_PRODUCT | awk -F_ '{ print $2 }')"

	_e_pending_success "Breakfast finished"
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
			_move_build
			_clean_old_builds
		else
			CURRENT_POST_BUILD_COMMAND_EXIT_CODE=0
			CURRENT_MOVE_BUILD_EXIT_CODE=0
			CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=0
		fi
	else
		_e_pending_error "Brunch of config ${CURRENT_CONFIG} failed after ${CURRENT_BRUNCH_RUN_TIME}"
		_paste_log
	fi
}

function _move_build () {
	if [ "${CURRENT_TARGET_DIR}" ]; then
		if [ -d "${CURRENT_TARGET_DIR}/" ]; then
			_e_notice "Moving files to target directory..."
			_exec_command "mv ${CURRENT_OUTPUT_FILEPATH}* ${CURRENT_TARGET_DIR}/" "_e_warning \"Something went wrong while moving the build\""
			CURRENT_MOVE_BUILD_EXIT_CODE=$?
		else
			_e_error "${CURRENT_TARGET_DIR}/ is not a Directory. Will not move the File."
		fi
	else
		CURRENT_MOVE_BUILD_EXIT_CODE=0
	fi
}

function _pre_build_command () {
	if [ ${CURRENT_PRE_BUILD_COMMAND} ]; then
		_e_pending "pre build command..."
		_exec_command "${CURRENT_PRE_BUILD_COMMAND}" "_e_warning \"Something went wrong while running your pre build command\"" "_e_success \"Succesfully run pre build command\""
		CURRENT_PRE_BUILD_COMMAND_EXIT_CODE=$?
	else
		CURRENT_PRE_BUILD_COMMAND_EXIT_CODE=0
	fi
}

function _post_build_command () {
	if [ ${CURRENT_POST_BUILD_COMMAND} ]; then
		_e_pending "post build command..."
		_exec_command "${CURRENT_POST_BUILD_COMMAND}" "_e_warning \"Something went wrong while running your post build command\"" "_e_success \"Succesfully run post build command\""
		CURRENT_POST_BUILD_COMMAND_EXIT_CODE=$?
	else
		CURRENT_POST_BUILD_COMMAND_EXIT_CODE=0
	fi
}

function _clean_old_builds () {
	if [ "${CURRENT_CLEANUP_OLDER_THAN}" ]; then
		_e_pending "Running cleanup of old builds..."
		if [ "${CURRENT_TARGET_DIR}" ] && [ -d "${CURRENT_TARGET_DIR}/" ]; then
			_exec_command "CURRENT_CLEANED_FILES=\"$(find ${CURRENT_TARGET_DIR}/ -name "omni-*-${CURRENT_DEVICE}-HOMEMADE.zip*" -type f -mtime +${CURRENT_CLEANUP_OLDER_THAN} -delete)\""
		else
			_exec_command "CURRENT_CLEANED_FILES=\"$(find `dirname ${CURRENT_OUTPUT_FILEPATH}` -name "omni-${PLATFORM_VERSION}-*-${CURRENT_DEVICE}-HOMEMADE.zip*" -type f -mtime +${CURRENT_CLEANUP_OLDER_THAN} -delete)\""
		fi
		CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=$?
		if [ "${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE}" != 0 ] && [ ! "${CURRENT_CLEANED_FILES}" ]; then
			_e_pending_success "Cleanup skipped, nothing to clean up for ${CURRENT_CONFIG}."
		elif [ "${CURRENT_CLEANED_FILES}" ]; then
			_e_pending_success "Cleanup finished, removed the following files: ${CURRENT_CLEANED_FILES}"
		elif [ "${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE}" != 0 ]; then
			_e_pending_error "Something went wrong while cleaning builds for ${CURRENT_CONFIG}." "${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE}"
		fi
	else
		CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=0
	fi
}

function _send_mail () {
	if [ ${MAIL_BIN} ] && ([ "${CURRENT_MAIL}" ] || [ "${CURRENT_ADMIN_MAIL}" ]); then
		if ${CURRENT_BUILD_STATUS}; then
			_generate_user_message "Build for ${CURRENT_DEVICE} was successfully finished after ${CURRENT_BRUNCH_RUN_TIME}\n"
			_generate_admin_message "Used config \"${CURRENT_CONFIG}\"\n"
			if [ "${CURRENT_DOWNLOAD_LINK}" ]; then
				_generate_user_message "You can download your Build at ${CURRENT_DOWNLOAD_LINK}\n\n"
			fi

			if [ -f ${CURRENT_CHANGELOG} ]; then
				_generate_user_message "$($(which cat) ${CURRENT_CHANGELOG})"
			fi

			if [ "${CURRENT_CLEANED_FILES}" ]; then
				_generate_admin_message "Removed the following files:"
				_generate_admin_message "${CURRENT_CLEANED_FILES}"
			fi
		else
			_generate_user_message "Build has failed after ${CURRENT_BRUNCH_RUN_TIME}.\n\n"
			if [ -f ${CURRENT_LOG} ]; then
				_generate_admin_message "Logfile attached"
				cat ${CURRENT_LOG} | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" > ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.log
				_exec_command "tar -C ${DINNER_TEMP_DIR} -zchf ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.log.tgz dinner_${CURRENT_CONFIG}.log"
				LOGFILE="-a \"${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}.log.tgz\""
			else
				_generate_admin_message "ERROR: Logfile not found"
			fi
			if [ -f ${CURRENT_ERRLOG} ]; then
				_generate_admin_message "Error Logfile attached"
				cat ${CURRENT_ERRLOG} | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" > ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}_error.log
				_exec_command "tar -C ${DINNER_TEMP_DIR} -zchf ${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}_error.log.tgz dinner_${CURRENT_CONFIG}_error.log"
				ERRLOGFILE="-a \"${DINNER_TEMP_DIR}/dinner_${CURRENT_CONFIG}_error.log.tgz\""
			else
				_generate_admin_message "ERROR: Error Logfile not found"
			fi
		fi

		_generate_user_message "\e[21m"

		if [ ${CURRENT_MAIL} ]; then
			_e_pending "Sending User E-Mail..."
		_exec_command "$(which cat) \"${DINNER_TEMP_DIR}/mail_user_message.txt\" | ${ANSI2HTML_BIN} | ${MAIL_BIN} -e \"set content_type=text/html\" -s \"[Dinner] Build for ${CURRENT_DEVICE} ${CURRENT_STATUS} (${CURRENT_BRUNCH_RUN_TIME})\" \"${CURRENT_MAIL}\"" "_e_pending_error \"Something went wrong while sending User E-Mail\"" "_e_pending_success \"Successfully send User E-Mail\""
			CURRENT_SEND_MAIL_EXIT_CODE=$?
		fi

		if [ ${CURRENT_ADMIN_MAIL} ]; then
			_e_pending "Sending Admin E-Mail..."
			_exec_command "$(which cat) \"${DINNER_TEMP_DIR}/mail_user_message.txt\" \"${DINNER_TEMP_DIR}/mail_admin_message.txt\" | ${ANSI2HTML_BIN} | ${MAIL_BIN} -e \"set content_type=text/html\" -s \"[Dinner] Build for ${CURRENT_DEVICE} ${CURRENT_STATUS} (${CURRENT_BRUNCH_RUN_TIME})\" \"${CURRENT_ADMIN_MAIL}\" ${LOGFILE} ${ERRLOGFILE}" "_e_pending_error \"Something went wrong while sending Admin E-Mail\""  "_e_pending_success \"Successfully send Admin E-Mail\""
			CURRENT_SEND_MAIL_EXIT_CODE=$(($CURRENT_SEND_MAIL_EXIT_CODE + $?))
		fi
	else
		CURRENT_SEND_MAIL_EXIT_CODE=0
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
		_exec_command "make ${CURRENT_DINNER_MAKE}" '_e_pending_error "Failed"' '_e_pending_success "Done"'
		if ${CURRENT_MAKE_ONLY}; then
			_check_current_config
			continue
		fi
	fi
}

function _check_current_config () {
	CURRENT_CONFIG_EXIT_CODE=$(( \
		${SYNC_REPO_EXIT_CODE} \
		+${CURRENT_BRUNCH_DEVICE_EXIT_CODE} \
		+${CURRENT_MOVE_BUILD_EXIT_CODE} \
		+${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE} \
		+${CURRENT_SEND_MAIL_EXIT_CODE} \
	))
	if ${CURRENT_BUILD_SKIPPED}; then
		SUCCESS_CONFIGS="${SUCCESS_CONFIGS}\"${CURRENT_CONFIG}\" "
	elif ${CURRENT_BUILD_STATUS} && [ "${CURRENT_CONFIG_EXIT_CODE}" -eq 0 ]; then
		SUCCESS_CONFIGS="${SUCCESS_CONFIGS}\"${CURRENT_CONFIG}\" "
		_set_lastbuild
	elif ${CURRENT_BUILD_STATUS} && [ "${CURRENT_CONFIG_EXIT_CODE}" -gt 0 ]; then
		WARNING_CONFIGS="${WARNING_CONFIGS}\"${CURRENT_CONFIG}\" "
	elif ! ${CURRENT_BUILD_STATUS} && [ "${CURRENT_CONFIG_EXIT_CODE}" -eq 0 ]; then
		_e_error "Buildcheck for config \"${CURRENT_CONFIG}\" has failed but overall exit code is fine" "${CURRENT_CONFIG_EXIT_CODE}"
		FAILED_CONFIGS="${FAILED_CONFIGS}\"${CURRENT_CONFIG}\" "
	elif ! ${CURRENT_BUILD_STATUS}; then
		FAILED_CONFIGS="${FAILED_CONFIGS}\"${CURRENT_CONFIG}\" "
	else
		_e_error "Could not determine status for config \"${CURRENT_CONFIG}\"" "${CURRENT_CONFIG_EXIT_CODE}"
	fi
	DINNER_EXIT_CODE=$((${DINNER_EXIT_CODE}+${CURRENT_CONFIG_EXIT_CODE}))
}

function _set_lastbuild () {
	echo $(date +%m/%d/%Y) > ${CURRENT_LASTBUILD_MEM}
}

function _get_changelog () {
	_e_pending "Gathering Changes since last successfull build..."
	if [ -f "${CURRENT_LASTBUILD_MEM}" ]; then
		LASTBUILD=$($(which cat) ${CURRENT_LASTBUILD_MEM})

		echo -e "\nChanges since last build ${LASTBUILD}"  > ${CURRENT_CHANGELOG}
		echo -e "=====================================================\n"  >> ${CURRENT_CHANGELOG}
		find ${REPO_DIR} -name .git | sed 's/\/.git//g' | sed 'N;$!P;$!D;$d' | while read line
		do
			cd $line
			log=$(git log --pretty="%an - %s" --since=${LASTBUILD} --date-order)
			project=$(git remote -v | head -n1 | awk '{print $2}' | sed 's/.*\///' | sed 's/\.git//')
			if [ ! -z "$log" ]; then
				origin=`grep "$project" ${REPO_DIR}/.repo/manifest.xml | awk {'print $4'} | cut -f2 -d '"'`

				if [ "$origin" = "bam" ]; then
						proj_credit=JELLYBAM
				elif [ "$origin" = "aosp" ]; then
						proj_credit=AOSP
				elif [ "$origin" = "cm" ]; then
						proj_credit=CyanogenMod
				else
						proj_credit="OmniROM"
				fi

				echo "$proj_credit Project name: $project" >> ${CURRENT_CHANGELOG}

				echo "$log" | while read line
				do
					echo "  .$line" >> ${CURRENT_CHANGELOG}
				done

				echo "" >> ${CURRENT_CHANGELOG}
			fi
		done
		if ${CURRENT_CHANGELOG_ONLY}; then
			CURRENT_BUILD_SKIPPED=true
			[[ -f ${CURRENT_CHANGELOG} ]] && _e_pending_success "Showing changelog:" && cat ${CURRENT_CHANGELOG} || _e_pending_error "No Changelog found"
			_check_current_config
			continue
		else
			_e_pending_success "Successfully gathered changes."
		fi
	else
		_e_pending_warn "Skipping gathering changes, no successfull build for config \"${CURRENT_CONFIG}\" found."
		if ${CURRENT_CHANGELOG_ONLY}; then
			CURRENT_BUILD_SKIPPED=true
			_e_pending "Searching last changelog..."
			sleep 3
			[[ -f ${CURRENT_CHANGELOG} ]] && _e_pending_success "Showing last changelog:" && cat ${CURRENT_CHANGELOG} || _e_pending_error "No Changelog found"
			_check_current_config
			continue
		fi
	fi

}

function _cleanup () {
	rm ${DINNER_TEMP_DIR}/*
	eval "find ${DINNER_MEM_DIR} $(_print_configs '! -name *%s* ') ! -name .empty -type f -exec rm {} \;"
	eval "find ${DINNER_LOG_DIR} $(_print_configs '! -name *%s* ') ! -name .empty ! -name dinner* -type f -exec rm {} \;"
	eval "find ${REPO_DIR}/.repo/local_manifests/ -name dinner* $(_print_configs '! -name *%s* ') -type f -exec rm {} \;"

	for ENV_VAR in ${BACKUP_ENV[@]}; do
		_exec_command "export ${ENV_VAR}"
	done

}

function _paste_log () {
	if ${PASTE_LOG} && ! ${DINNER_CRON}; then
		tail -300 ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log} > ${DINNER_TMP_DIR}/paste.log
		printf "JAVA_HOME=${JAVA_HOME}" >> ${DINNER_TMP_DIR}/paste.log
		printf "JAVAC_VERSION=${JAVAC_VERSION}" >> ${DINNER_TMP_DIR}/paste.log
		printf "${DINNER_LOG_COMMENT}\nThis Combined Log contains messages from STDOUT and STDERR\n\n" >> ${DINNER_TMP_DIR}/paste.log
		printf "${DINNER_LOG_COMMENT}\nThis Error Log contains only messages from STDERR\n\n" >> ${DINNER_TMP_DIR}/paste.log
		eval "$(which curl) --data-urlencode text@${DINNER_TMP_DIR}/paste.log ${PASTE_URL}"
		rm ${DINNER_TMP_DIR}/paste.log
	else
		_e_error "See logfiles for more information" "NULL" "Combined Log: ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log}" "Error log: ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log}"
	fi
}

function _clear_logs () {
	[[ ${1} ]] && [[ ${1} =~ ^[0-9]+$ ]] && local OLDER_THAN="-mtime ${1}" || local OLDER_THAN=""
	[[ ${2} ]] && local CONFIG="${2}" || local CONFIG=""
	_e_pending "Cleaning logfiles for ${CONFIG}..."
	LOGFILE_RESULT=$(find ${DINNER_LOG_DIR} -name "*${CONFIG}*.log" -type f ${OLDER_THAN})
	if [ "${LOGFILE_RESULT}" ]; then
		for RMLOGFILE in ${LOGFILE_RESULT}; do
			rm ${RMLOGFILE}
		done
		_e_pending_success "Successfull cleaned following logs for ${CONFIG}:" "${LOGFILE_RESULT}"
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
		"cook")
			CURRENT_CONFIG=${2}
			;;
		*)
			_e_fatal "Unknown command '$1'" $EX_USAGE
			;;
	esac

	_check_prerequisites

	_get_breakfast_variables

	_dinner_make

	_generate_local_manifest

	_sync_repo

	_repo_pick

	_get_changelog

	_pre_build_command

	_brunch_device

	_check_current_config

	_send_mail

	_cleanup
}
