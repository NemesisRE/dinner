#!/bin/bash
##################################################
#
# vim: ai:ts=4:sw=4:noet:sts=4:ft=sh
#
# Copyright 2013, Steven Koeberich (nemesissre@gmail.com)
#
# Title:		dinner.sh
# Author:		Steven "NemesisRE" Koeberich
# Date: 		20131117
# Version:		1.1
# Description:	Builds Roms automatically
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
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
CONVERT_TO_HTML=$(which ansi2html)							# install package kbtin to use this feature
SHOW_VERBOSE="> /dev/null 2>&1"

######################
#
#	function _usage
#
#
function _usage() {
echo $"Usage: ${0} [-n \"smith@example.com\"] [-t \'/var/www/awsome-download-dir\'] [-r \'scp \$\{OUTPUT_FILE\} example.com:\' ][-l \"http://example.com/download/omnirom\"] [-c 7] [-v] [-- i9300 mako ]"
cat<<EOF

Options:
	-n		Send notification to given Mail-Adress
	-t		Move files into given Directorie
	-r		Run command on successful build
	-l		If you choose a target dir you may want put
			a download link into the mail message
	-c		Cleanup builds older then N days
	-v		Verbose Output
	-h		See this Message

EOF
}

function _e_notice () {
	echo -e "NOTICE: ${1}"
}

function _e_warning () {
	echo -e "WARNING:Something went wrong ${1} (Exit Code ${2})"
}

function _e_error () {
	echo -e "ERROR: ${1}"
}

function _e_fatal () {
	echo -e "FATAL: ${1}"
	exit 1
}

function _check_prerequisites () {
	if [ -f "dinner.conf" ]; then
		. dinner.conf
	else
		cat<<- EOF > dinner.conf
		REPO_DIR=""
		LOG_DIR=""
		MAIL=''				# set this if you want always an email
		ADMIN_MAIL=''			# set this if you want always an email (with logs)
		TARGET_DIR=''			# set this if you want always move your build to the given directorie
		CLEANUP_OLDER_THEN=''		# set this if you want always automatic cleanup
		DOWNLOAD_LINK=''		# set this if you want always a download link
		RUN_COMMAND=''			# set this if you want always run a command after a build was successful
		BUILD_FOR_DEVICE=""		# set this if you want always build for the given device/s
		DINNER_TEMP_DIR=""		# this is the place to store temp. files of this script
		EOF
		_e_fatal "No dinner config found, created it."
	fi

	if [ -f "${REPO_DIR}/build/envsetup.sh" ]; then
		. ${REPO_DIR}/build/envsetup.sh
	else
		_e_fatal "envsetup could not be found."
	fi


	if [ "${TARGET_DIR}" ]; then
		TARGET_DIR=$(echo "${TARGET_DIR}"|sed 's/\/$//g')
	fi

	if [ "${LOG_DIR}" ]; then
		LOG_DIR=$(echo "${LOG_DIR}"|sed 's/\/$//g')
	fi

	if [ -z "${BUILD_FOR_DEVICE}" ]; then
		_e_fatal "No Device given! Stopping..."
	fi

	if [ ! -d "${LOG_DIR}" ]; then
		mkdir -p "${LOG_DIR}"
	fi

	if [ ! -d "${DINNER_TEMP_DIR}" ]; then
		mkdir -p "${DINNER_TEMP_DIR}"
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
		_e_warning "while brunch the ${DEVICE}, see logfile for more information" "${CURRENT_BRUNCH_DEVICE_EXIT_CODE}"
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
		e_error "${CURRENT_TARGET_DIR}/ is not a Directory. Will not move the File."
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
	MAIL_MESSAGE="\e[1mBuild Status:\n\n"
	ADMIN_MAIL_MESSAGE=""
	if ${CURRENT_BUILD_STATUS}; then
		MAIL_MESSAGE+="Build for ${DEVICE} was successfull finished after ${CURRENT_BRUNCH_RUN_TIME}\n"
		if [ "${CURRENT_DOWNLOAD_LINK}" ]; then
			MAIL_MESSAGE+="You can download your Build at ${CURRENT_DOWNLOAD_LINK}\n\n"
		fi
		if [ "${CURRENT_CLEANED_FILES}" ]; then
			ADMIN_MAIL_MESSAGE+="Removed the following files:\n"
			ADMIN_MAIL_MESSAGE+=${CURRENT_CLEANED_FILES}
		fi
	else
		MAIL_MESSAGE+="Build was has failed after ${CURRENT_BRUNCH_RUN_TIME}.\n\n"
		ADMIN_MAIL_MESSAGE+="Logfile:"
		ADMIN_MAIL_MESSAGE+=$(cat ${LOG_DIR}/brunch_${DEVICE}.log)
	fi
	MAIL_MESSAGE+="\e[21m"
	if [ "${CURRENT_MAIL}" ]; then
		if [ ${CONVERT_TO_HTML} ]; then
			echo -e "${MAIL_MESSAGE}" | ${CONVERT_TO_HTML} | ${MAIL_BIN} -a "Content-type: text/html" -s "Finished dinner." "${CURRENT_MAIL}"
		else
			echo -e "${MAIL_MESSAGE}" | ${MAIL_BIN} -s "Finished dinner." "${CURRENT_MAIL}"
		fi
	fi
	if [ "${CURRENT_ADMIN_MAIL}" ]; then
		FULL_ADMIN_MESSAGE=$(echo -e "${MAIL_MESSAGE}${ADMIN_MAIL_MESSAGE}")
		if [ ${CONVERT_TO_HTML} ]; then
			echo -e "${FULL_ADMIN_MESSAGE}" | ${CONVERT_TO_HTML} | ${MAIL_BIN} -a "Content-type: text/html" -s "Finished dinner." "${CURRENT_ADMIN_MAIL}"
		else
			echo -e "${FULL_ADMIN_MESSAGE}" | ${MAIL_BIN} -s "Finished dinner." "${CURRENT_ADMIN_MAIL}"
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
	echo `date` > ${DINNER_TEMP_DIR}/lastbuild.txt
}

function _get_changelog () {
	_e_notice "Gathering Changes since last build..."
	LASTBUILD=`cat ${DINNER_TEMP_DIR}/lastbuild.txt`

	echo -e "Changes since last build ${LASTBUILD}"  > ${DINNER_TEMP_DIR}/changes.txt
	echo -e "=====================================================\n"  >> ${DINNER_TEMP_DIR}/changes.txt
	repo forall -c git --no-pager log  --date-order --since="${LASTBUILD}" --format=email >> ${DINNER_TEMP_DIR}/changes.txt
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

	_sync_repo

	_get_changelog

	for DEVICE in ${BUILD_FOR_DEVICE}; do
		CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE=1
		_get_breakfast_variables
		eval CURRENT_TARGET_DIR="${TARGET_DIR}"
		eval CURRENT_MAIL="${MAIL}"
		eval CURRENT_ADMIN_MAIL="${ADMIN_MAIL}"
		eval CURRENT_OUTPUT_FILE="${OUT_DIR}/target/product/${DEVICE}/omni-${PLATFORM_VERSION}-$(date +%Y%m%d)-${DEVICE}-HOMEMADE.zip"
		eval CURRENT_BUILD_STATUS=false
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
while getopts ":n:t:l:c:vh" opt; do
	case ${opt} in
		"n")
			MAIL='${OPTARG}'
		;;
		"t")
			TARGET_DIR='${OPTARG}'
		;;
		"r")
			RUN_COMMAND='${OPTARG}'
		;;
		"l")
			DOWNLOAD_LINK='${OPTARG}'
		;;
		"c")
			CLEANUP_OLDER_THEN="${OPTARG}"
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
	BUILD_FOR_DEVICE="${@}"
fi

_main

exit 0

