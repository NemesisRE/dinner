#!/bin/bash
##################################################
#
# vim: ai:ts=4:sw=4:noet:sts=4:ft=sh
#
# Copyright 2013, Steven Koeberich (nemesissre@gmail.com)
#
# Title:			dinner.sh
# Author:			Steven "NemesisRE" Koeberich
# Contributors:		ToeiRei
# Creation Date:	20131117
# Version:			1.1
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

#set -e 	#do not enable otherwise brunch will fail
#set -x
trap "echo \"Received SIGINT or SIGTERM, exiting..\"; exit 1;" SIGINT SIGTERM

#For compatibility set Language to en_US.UTF8 and timezone to UTC
export LANGUAGE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"
export TZ="/usr/share/zoneinfo/UTC"

#Make us of CCACHE
export USE_CCACHE=1

# Define global variables
MAIL_BIN=$(which mail)
CONVERT_TO_HTML=$(which ansi2html)			# install package kbtin to use this feature
SHOW_VERBOSE="> /dev/null 2>&1"
SKIP_SYNC=false

######################
#
#	function _usage
#
#
function _usage() {
echo "Usage: ${0} [-n \"smith@example.com\"] [-t \'/var/www/awsome-download-dir\'] [-r \'scp \$\{OUTPUT_FILE\} example.com:\' ][-l \"http://example.com/download/omnirom\"] [-c 7] [-v] [-- i9300 mako ]"
$(which cat)<<EOF

Options:
	-n		Send notification to given Mail-Adress
	-t		Move files into given Directory
	-r		Run command on successful build
	-l		If you choose a target dir you may want put
			a download link into the mail message
	-c		Cleanup builds older then N days
	-s		Skip Sync
	-v		Verbose Output
	-h		See this Message

EOF
}

function _e_notice () {
	echo -e "NOTICE:\t\t${1}"
}

function _e_warning () {
	echo -e "WARNING:\tSomething went wrong ${1} (Exit Code ${2})"
}

function _e_error () {
	echo -e "ERROR:\t\t${1}"
}

function _e_fatal () {
	echo -e "FATAL:\t\t${1}\n\t\tStopping..."
	exit 1
}

function _generate_user_message () {
	if [ ! -f "${DINNER_TEMP_DIR}/user_message_${DEVICE}.txt" ]; then
		touch "${DINNER_TEMP_DIR}/user_message_${DEVICE}.txt"
	fi
	echo -e "${1}" >> "${DINNER_TEMP_DIR}/user_message_${DEVICE}.txt"
}

function _generate_admin_message () {
	if [ ! -f "${DINNER_TEMP_DIR}/mail_admin_message_${DEVICE}.txt" ]; then
		touch "${DINNER_TEMP_DIR}/mail_admin_message_${DEVICE}.txt"
	fi
	echo -e "${1}" >> "${DINNER_TEMP_DIR}/admin_message_${DEVICE}.txt"
}

function _check_prerequisites () {
	if [ -f "dinner.conf" ]; then
		. dinner.conf
		if [ ${USE_CONFIG} ]; then
			if [ -f "./config.d/${USE_CONFIG}" ]; then
				. ./config.d/${USE_CONFIG}
			else
				_e_fatal "./config.d/${USE_CONFIG} not found!"
			fi
		elif [ -f "./config.d/default" ]; then
			. ./config.d/default
		else
			_e_fatal "default config not found!"
		fi

		# Check essentials
		if [ ! "${REPO_DIR}" ]; then
			_e_fatal "REPO_DIR is not set!"
		elif [ ! ${BUILD_FOR_DEVICE} ] || [ ${PROMT_BUILD_FOR_DEVICE} ]; then
			_e_fatal "No Device given! Stopping..."
		fi

		if [ ${PROMT_BUILD_FOR_DEVICE} ];then
			BUILD_FOR_DEVICE=${PROMT_BUILD_FOR_DEVICE}
		fi
	else
		_e_fatal "No dinner config found, created it. Please copy dinner.conf.dist\n\t\tto dinner.conf and change the Variables to your needs."
	fi

	if [ ! -d "${REPO_DIR}/.repo" ]; then
		_e_fatal "${REPO_DIR} is not a Repo!"
	elif [ -f "${REPO_DIR}/build/envsetup.sh" ]; then
		. ${REPO_DIR}/build/envsetup.sh
	else
		_e_fatal "${REPO_DIR}/build/envsetup.sh could not be found."
	fi

	if [ "${TARGET_DIR}" ]; then
		TARGET_DIR=$(echo "${TARGET_DIR}"|sed 's/\/$//g')
	fi

	if [ "${LOG_DIR}" ]; then
		LOG_DIR=$(echo "${LOG_DIR}"|sed 's/\/$//g')
		if [ ! -d "${LOG_DIR}" ]; then
			mkdir -p "${LOG_DIR}"
			if [ ${?} != 0 ]; then
				_e_fatal "Could not create Log directory (${LOG_DIR})!"
			fi
		fi
	else
		_e_fatal "LOG_DIR is not set!"
	fi

	if [ "${DINNER_TEMP_DIR}" ]; then
		DINNER_TEMP_DIR=$(echo "${DINNER_TEMP_DIR}"|sed 's/\/$//g')
		if [ ! -d "${DINNER_TEMP_DIR}" ]; then
			mkdir -p "${DINNER_TEMP_DIR}"
			if [ ${?} != 0 ]; then
				_e_fatal "Could not create TMP directory (${DINNER_TEMP_DIR})!"
			fi
		elif [ -f "${DINNER_TEMP_DIR}/mail_*_message_*.txt" ]; then
			rm "${DINNER_TEMP_DIR}/mail_*_message_*.txt"
		fi
	else
		_e_fatal "DINNER_TEMP_DIR is not set!"
	fi
}

function _sync_repo () {
	_e_notice "Running repo sync..."
	eval "repo sync ${SHOW_VERBOSE}"
	SYNC_REPO_EXIT_CODE=$?
	if [ "${SYNC_REPO_EXIT_CODE}" != 0 ]; then
		_e_warning "while doing repo sync" "${SYNC_REPO_EXIT_CODE}"
	fi
}

function _get_breakfast_variables () {
	for VARIABLE in `breakfast ${DEVICE} | sed -e 's/^=.*//' -e 's/[ ^I]*$//' -e '/^$/ d'`; do
		eval "${VARIABLE}"
	done
	if [ ${PLATFORM_VERSION} ]; then
		CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE=0
	else
		_e_warning "while getting breakfast variables" "${CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE}"
	fi
}

function _brunch_device () {
	_e_notice "Running brunch for ${DEVICE} with version ${PLATFORM_VERSION}..."
	eval "brunch ${DEVICE} 2>&1 | tee ${LOG_DIR}/brunch_${DEVICE}.log ${SHOW_VERBOSE}"
	CURRENT_BRUNCH_DEVICE_EXIT_CODE=${?}
	CURRENT_BRUNCH_RUN_TIME=$(tail ${LOG_DIR}/brunch_${DEVICE}.log | grep "real" | awk '{print $2}')
	if [ "${CURRENT_BRUNCH_DEVICE_EXIT_CODE}" != 0 ]; then
		_e_error "while brunch the ${DEVICE}, see logfile for more information" "${CURRENT_BRUNCH_DEVICE_EXIT_CODE}"
	fi
}

function _move_build () {
	if [ -d ${CURRENT_TARGET_DIR}/ ]; then
		_e_notice "Moving files to target directory..."
		mv ${CURRENT_OUTPUT_FILE}* ${CURRENT_TARGET_DIR}/
		CURRENT_MOVE_BUILD_EXIT_CODE=$?
		if [ "${CURRENT_MOVE_BUILD_EXIT_CODE}" != 0 ]; then
			_e_warning "while moving the build" "${CURRENT_MOVE_BUILD_EXIT_CODE}"
		fi
	else
		_e_error "${CURRENT_TARGET_DIR}/ is not a Directory. Will not move the File."
	fi
}

function _run_command () {
	_e_notice "Run command..."
	eval ${CURRENT_RUN_COMMAND} ${SHOW_VERBOSE}
	CURR]NT_RUN_COMMAND_EXIT_CODE=$?
	if [ "${CURRENT_RUN_COMMAND_EXIT_CODE}" != 0 ]; then
		_e_warning "while running your command" "${CURRENT_RUN_COMMAND_EXIT_CODE}"
	fi
}

function _clean_old_builds () {
	_e_notice "Running cleanup of old builds..."
	if [ "${CURRENT_TARGET_DIR}" ]; then
		CURRENT_CLEANED_FILES=$(find ${CURRENT_TARGET_DIR}/ -name "omni-${PLATFORM_VERSION}-*-${DEVICE}-HOMEMADE.zip*" -type f -mtime +${CLEANUP_OLDER_THEN} -delete)
	else
		CURRENT_CLEANED_FILES=$(find `dirname ${OUTPUT_FILE}` -name "omni-${PLATFORM_VERSION}-*-${DEVICE}-HOMEMADE.zip*" -type f -mtime +${CLEANUP_OLDER_THEN} -delete)
	fi
	CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=$?
	if [ "${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE}" != 0 ] && [ ! "${CURRENT_CLEANED_FILES}" ]; then
		CURRENT_CLEANED_FILES="Nothing to clean up for ${DEVICE}."
	elif [ "${CURRENT_CLEANED_FILES}" ]; then
		_e_notice "${CURRENT_CLEANED_FILES}"
	fi
	if [ "${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE}" != 0 ]; then
		_e_warning "while cleaning builds for ${DEVICE}." "${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE}"
	fi
}

function _send_mail () {
	_e_notice "Sending status mail..."
	_generate_user_message "\e[1mBuild Status:\n\n"
	if ${CURRENT_BUILD_STATUS}; then
		_generate_user_message "Build for ${DEVICE} was successfull finished after ${CURRENT_BRUNCH_RUN_TIME}\n"
		if [ "${CURRENT_DOWNLOAD_LINK}" ]; then
			_generate_user_message "You can download your Build at ${CURRENT_DOWNLOAD_LINK}\n\n"
		fi
		if [ "${CURRENT_CLEANED_FILES}" ]; then
			_generate_admin_message "Removed the following files:\n"
			_generate_admin_message "${CURRENT_CLEANED_FILES}"
		fi
	else
		_generate_user_message "Build was has failed after ${CURRENT_BRUNCH_RUN_TIME}.\n\n"
		_generate_admin_message "Logfile:"
		_generate_admin_message "$($(which cat) ${LOG_DIR}/brunch_${DEVICE}.log)"
	fi
	_generate_user_message "\e[21m"
	if [ "${CURRENT_MAIL}" ]; then
		if [ ${CONVERT_TO_HTML} ]; then
			$(which cat) "${DINNER_TEMP_DIR}/mail_user_message_${DEVICE}.txt" | ${CONVERT_TO_HTML} | ${MAIL_BIN} -a "Content-type: text/html" -s "Finished dinner." "${CURRENT_MAIL}"
		else
			$(which cat) "${DINNER_TEMP_DIR}/mail_user_message_${DEVICE}.txt" | ${MAIL_BIN} -s "Finished dinner." "${CURRENT_MAIL}"
		fi
	fi
	if [ "${CURRENT_ADMIN_MAIL}" ]; then
		if [ ${CONVERT_TO_HTML} ]; then
			$(which cat) "${DINNER_TEMP_DIR}/mail_user_message_${DEVICE}.txt" "${DINNER_TEMP_DIR}/mail_user_message_${DEVICE}.txt" | ${CONVERT_TO_HTML} | ${MAIL_BIN} -a "Content-type: text/html" -s "Finished dinner." "${CURRENT_ADMIN_MAIL}"
		else
			$(which cat) "${DINNER_TEMP_DIR}/mail_user_message_${DEVICE}.txt" "${DINNER_TEMP_DIR}/mail_user_message_${DEVICE}.txt" | ${MAIL_BIN} -s "Finished dinner." "${CURRENT_ADMIN_MAIL}"
		fi
	fi
	CURRENT_SEND_MAIL_EXIT_CODE=$?
	if [ "${CURRENT_SEND_MAIL_EXIT_CODE}" != 0 ]; then
		_e_warning "while sending E-Mail" "${CURRENT_SEND_MAIL_EXIT_CODE}"
	fi
}

function _check_build () {
	if [ -f "${CURRENT_OUTPUT_FILE}" ]; then
		CURRENT_OUT_FILE_SECONDS_SINCE_CREATION=$(/bin/date -d "now - $( /usr/bin/stat -c "%Y" ${CURRENT_OUTPUT_FILE} ) seconds" +%s)
		if [ "${CURRENT_OUT_FILE_SECONDS_SINCE_CREATION}" -lt "120" ] ; then
			CURRENT_BUILD_STATUS=true
		fi
	fi
}

function _set_lastbuild () {
	echo `date +"%m/%d/%Y"` > ${DINNER_TEMP_DIR}/lastbuild.txt
}

function _get_changelog () {
	if [ -f "${DINNER_TEMP_DIR}/lastbuild.txt" ]; then
	_e_notice "Gathering Changes since last build..."
	LASTBUILD=`$(which cat) ${DINNER_TEMP_DIR}/lastbuild.txt`

	echo -e "Changes since last build ${LASTBUILD}"  > ${DINNER_TEMP_DIR}/changes.txt
	echo -e "=====================================================\n"  >> ${DINNER_TEMP_DIR}/changes.txt


		find ${REPO_DIR} -name .git | sed 's/\/.git//g' | sed 'N;$!P;$!D;$d' | while read line; do
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

				echo "$proj_credit Project name: $project" >> ${DINNER_TEMP_DIR}/changes.txt

				echo "$log" | while read line; do
					echo "  .$line" >> ${DINNER_TEMP_DIR}/changes.txt
				done

				echo "" >> ${DINNER_TEMP_DIR}/changes.txt
			fi
		done
	fi
}


######################
#
#	function _main
#
#
function _main() {
	#Set initial exitcodes
	OVERALL_EXIT_CODE=0
	SYNC_REPO_EXIT_CODE=1

	_check_prerequisites

	cd "${REPO_DIR}"

	if ! ${SKIP_SYNC}; then
		_sync_repo
	fi

	_get_changelog

	for DEVICE in ${BUILD_FOR_DEVICE}; do
		CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE=1
		_get_breakfast_variables
		eval CURRENT_TARGET_DIR="${TARGET_DIR}"
		eval CURRENT_MAIL="${MAIL}"
		eval CURRENT_ADMIN_MAIL="${ADMIN_MAIL}"
		eval CURRENT_OUTPUT_FILE="${OUT_DIR}/target/product/${DEVICE}/omni-${PLATFORM_VERSION}-$(date +%Y%m%d)-${DEVICE}-HOMEMADE.zip"
		eval CURRENT_DOWNLOAD_LINK=${DOWNLOAD_LINK}

		CURRENT_BUILD_STATUS=false
		CURRENT_DEVICE_EXIT_CODE=1
		CURRENT_BRUNCH_DEVICE_EXIT_CODE=1
		CURRENT_MOVE_BUILD_EXIT_CODE=1
		CURRENT_RUN_COMMAND_EXIT_CODE=0
		CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=1
		CURRENT_SEND_MAIL_EXIT_CODE=1

		_brunch_device

		if [ "${CURRENT_BRUNCH_DEVICE_EXIT_CODE}" == 0 ]; then
			_check_build
			if ${CURRENT_BUILD_STATUS}; then
				if [ "${CURRENT_TARGET_DIR}" ]; then
					_move_build
				else
					CURRENT_MOVE_BUILD_EXIT_CODE=0
				fi

				if [ "${CLEANUP_OLDER_THEN}" ]; then
					_clean_old_builds
				else
					CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=0
				fi
			fi
		else
			CURRENT_MOVE_BUILD_EXIT_CODE=0
			CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=0
		fi


		if [ "${CURRENT_MAIL}" ] || [ "${CURRENT_ADMIN_MAIL}" ]; then
			_send_mail
		else
			CURRENT_SEND_MAIL_EXIT_CODE=0
		fi

		CURRENT_DEVICE_EXIT_CODE=$((${SYNC_REPO_EXIT_CODE}+${CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE}+${CURRENT_BRUNCH_DEVICE_EXIT_CODE}+${CURRENT_MOVE_BUILD_EXIT_CODE}+${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE}+${CURRENT_SEND_MAIL_EXIT_CODE}))
		if ! ${CURRENT_BUILD_STATUS} && [ "${CURRENT_DEVICE_EXIT_CODE}" -gt 0 ]; then
			_e_warning "buildcheck for ${DEVICE} has failed" "${CURRENT_DEVICE_EXIT_CODE}"
		elif ${CURRENT_BUILD_STATUS} && [ "${CURRENT_DEVICE_EXIT_CODE}" -gt 0 ]; then
			_e_warning "buildcheck for ${DEVICE} was successful but something else went wrong" "${CURRENT_DEVICE_EXIT_CODE}"
		else
			_e_notice "All jobs for ${DEVICE} finished successfully."
			_set_lastbuild
		fi
		OVERALL_EXIT_CODE=$((${OVERALL_EXIT_CODE}+${CURRENT_DEVICE_EXIT_CODE}))
	done
}

## Parameter handling
while getopts ":n:t:l:c:vhs" opt; do
	case ${opt} in
		"n")
			PROMT_MAIL='${OPTARG}'
		;;
		"t")
			PROMT_TARGET_DIR='${OPTARG}'
		;;
		"r")
			PROMT_RUN_COMMAND='${OPTARG}'
		;;
		"l")
			PROMT_DOWNLOAD_LINK='${OPTARG}'
		;;
		"c")
			PROMT_CLEANUP_OLDER_THEN="${OPTARG}"
		;;
		"s")
			SKIP_SYNC=true
		;;
		"v")
			SHOW_VERBOSE=""
		;;
		"h")
			_usage
			exit 0
		;;
		\?)
			echo "Invalid option: -${OPTARG}"
			_usage
			exit 1
		;;
		:)
			echo "Option -${OPTARG} requires an argument."
			_usage
			exit 1
		;;
	esac
done
shift $((${OPTIND}-1))

if [ "${@}" ]; then
	PROMT_BUILD_FOR_DEVICE="${@}"
fi

_main

exit 0

