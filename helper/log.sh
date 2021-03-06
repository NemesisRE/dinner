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


# Define some colors
TXTDEF="\e[0m"    # Revert to default
BLDRED="\e[1;31m" # Red - error
BLDGRN="\e[1;32m" # Green - success
BLDYLW="\e[1;33m" # Yellow - warning
BLDBLU="\e[1;34m" # Blue - no action/ignored
BLDPUR="\e[1;35m" # Purple - fatal
BLDCYN="\e[1;36m" # Cyan - pending
BLDWHT="\e[1;37m" # White - notice
HALIGN="13"

function _e {
	unset STATUS_COLOR STATUS_NAME STATUS_MESSAGE
	local STATUS_COLOR=${1}
	local STATUS_NAME=${2}
	local STATUS_MESSAGE=${3}
	shift 3
	if [[ ${STATUS_NAME} =~ ^ERROR$|^ABORT$ ]] || ! ${DINNER_CRON}; then
		printf "${STATUS_COLOR}%${HALIGN}b:\t%b\n${TXTDEF}" "${STATUS_NAME}" "${STATUS_MESSAGE}"
		printf "%${HALIGN}b:\t%b\n" "${STATUS_NAME}" "${STATUS_MESSAGE}" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log} )

		for LINE in "$@"; do
			printf "${STATUS_COLOR}%13b\t%b${TXTDEF}" " " "${LINE}\n"
			printf "%$((HALIGN+1))b\t%b" " " "${LINE}\n" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log} )
		done
	fi
}

function _e_pending {
	if ! ${DINNER_CRON}; then
		unset PENDING_MESSAGE PENDING_STATUS PENDING_COLOR PENDING_SLEEP
		[[ ${1} ]] && [[ "${1}" = " " ]] && local PENDING_MESSAGE="" || local PENDING_MESSAGE=${1}
		[[ ${2} ]] && local PENDING_STATUS=${2} || local PENDING_STATUS="RUNNING"
		[[ ${3} ]] && local PENDING_COLOR=${3} || local PENDING_COLOR="${BLDCYN}"
		[[ ${4} ]] && local PENDING_SLEEP=${4} || local PENDING_SLEEP="3"
		printf "${PENDING_COLOR}%${HALIGN}b:\t%b${TXTDEF}" "${PENDING_STATUS}" "${PENDING_MESSAGE}"
		printf "%${HALIGN}b:\t%b\n" "${PENDING_STATUS}" "${PENDING_MESSAGE}"  | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log} )
		sleep ${PENDING_SLEEP}
	fi
}

function _e_pending_notice () {
	unset PENDING_SUCCESS_MESSAGE
	[[ ${1} ]] && local PENDING_NOTICE_MESSAGE=${1} && shift 1
	_e "\r\033[K${BLDWHT}" "NOTICE" "${PENDING_NOTICE_MESSAGE}" "${@}"
}

function _e_pending_success () {
	unset PENDING_SUCCESS_MESSAGE
	[[ ${1} ]] && local PENDING_SUCCESS_MESSAGE=${1} && shift 1
	_e "\r\033[K${BLDGRN}" "FINISHED" "${PENDING_SUCCESS_MESSAGE}" "${@}"

}

function _e_pending_skipped () {
	unset PENDING_SKIPPED_MESSAGE
	[[ ${1} ]] && local PENDING_SKIPPED_MESSAGE=${1} && shift 1
	_e "\r\033[K${BLDBLU}" "SKIPPED" "${PENDING_SKIPPED_MESSAGE}" "${@}"
}

function _e_pending_warn () {
	unset PENDING_WARN_MESSAGE
	[[ ${1} ]] && local PENDING_WARN_MESSAGE=${1} && shift 1
	_e "\r\033[K${BLDYLW}" "WARNING" "${PENDING_WARN_MESSAGE}" "${@}"
}

function _e_pending_error () {
	unset PENDING_ERROR_MESSAGE EXIT_CODE
	[[ ${1} ]] && local PENDING_ERROR_MESSAGE=${1} && shift 1
	[[ ${1} ]] && [[ ${1} =~ ^[0-9]+$ ]] && local EXIT_MCODE="(Exit Code ${1})" && shift 1
	_e "\r\033[K${BLDRED}" "ERROR" "${PENDING_ERROR_MESSAGE} ${EXIT_MCODE}" "${@}"
}

function _e_pending_fatal () {
	unset PENDING_FATAL_MESSAGE EXIT_CODE
	[[ ${1} ]] && local PENDING_FATAL_MESSAGE=${1} && shift 1
	[[ ${1} ]] && [[ ${1} =~ ^[0-9]+$ ]] && local EXIT_CODE="${1}" && local EXIT_MCODE="(Exit Code ${1})" && shift 1
	_e "\r\033[K${BLDPUR}" "ABORT" "${PENDING_FATAL_MESSAGE} ${EXIT_MCODE}" "${@}" "To paste the error log run: dinner pastelog ${CURRENT_CONFIG:-dinner}" "Or look into the logfiles for more information" "Combined Log: ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log}" "Error log: ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log}" "Stopping..."
	exit ${EXIT_CODE:-1}
}

function _e_notice () {
	unset NOTICE_MESSAGE
	[[ ${1} ]] && local NOTICE_MESSAGE=${1} && shift 1
	_e "${BLDWHT}" "NOTICE" "${NOTICE_MESSAGE}" "${@}"
}

function _e_success () {
	unset SUCCESS_MESSAGE
	[[ ${1} ]] && local SUCCESS_MESSAGE=${1} && shift 1
	_e "${BLDGRN}" "FINISHED" "${SUCCESS_MESSAGE}" "${@}"
}

function _e_skipped () {
	unset SKIPPED_MESSAGE
	[[ ${1} ]] && local SKIPPED_MESSAGE=${1} && shift 1
	_e "${BLDBLU}" "SKIPPED" "${SKIPPED_MESSAGE}" "${@}"
}

function _e_warn () {
	unset WARN_MESSAGE
	[[ ${1} ]] && local WARN_MESSAGE=${1} && shift 1
	_e "${BLDYLW}" "WARNING" "${WARN_MESSAGE}" "${@}"
}

function _e_error () {
	unset EXIT_MESSAGE EXIT_CODE ERROR_MESSAGE
	[[ ${1} ]] && local ERROR_MESSAGE=${1} && shift 1
	[[ ${1} ]] && [[ ${1} =~ ^[0-9]+$ ]] && local EXIT_MCODE="(Exit Code ${1})" && shift 1
	_e "${BLDRED}" "ERROR" "${ERROR_MESSAGE} ${EXIT_MCODE}" "${@}"
}

function _e_fatal () {
	unset EXIT_MESSAGE EXIT_CODE
	[[ ${1} ]] && local FATAL_MESSAGE=${1}
	[[ ${2} ]] && [[ ${2} =~ ^[0-9]+$ ]] && local EXIT_CODE="${2}" && local EXIT_MCODE="(Exit Code ${2})" && shift 2 || shift 1
	_e "${BLDPUR}" "ABORT" "${FATAL_MESSAGE} ${EXIT_MCODE}" "${@}" "To paste the error log run: dinner pastelog ${CURRENT_CONFIG:-dinner}" "See logfiles for more information" "Combined Log: ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log}" "Error log: ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log}" "Stopping..."
	exit ${EXIT_CODE:-1}
}

function _log_msg () {
	unset LOG_MESSAGE
	[[ ${1} ]] && local LOG_MESSAGE=${1} && shift 1
	printf "%${HALIGN}b:\t%b\n" "LOGMESSAGE" "${LOG_MESSAGE}" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log} )
}

##
# _exec_command
#
# param1 = command
# param2 = Fail command
# param3 = Success command
#
function _exec_command () {
	local COMMAND=${1}
	[[ ${2} ]] && local FAIL=${2} || local FAIL="NOTSET"
	[[ ${3} ]] && local SUCCESS=${3} || local SUCCESS="NOTSET"
	if ${SHOW_VERBOSE}; then
		# log STDOUT and STDERR, send both to STDOUT
		_e "\n${BLDYLW}" "COMMAND" "${COMMAND}"
		eval "${COMMAND} &> >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log} ) 2> >( tee -a ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log} )"
	else
		# log STDOUT and STDERR but send only STDERR to STDOUT
		printf "%13b:\t%b\n" "COMMAND" "${COMMAND}" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log} )
		eval "${COMMAND} &>>${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log} 2>>${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log}"
	fi
	local EXIT_CODE=${?}
	printf "%13b:\t%b\n" "EXIT CODE" "${EXIT_CODE}" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_error.log} )
	if [ "${EXIT_CODE}" != 0 ] && [ "${FAIL}" != "NOTSET" ]; then
		eval ${FAIL} ${EXIT_CODE}
	elif [ "${SUCCESS}" != "NOTSET" ]; then
		eval ${SUCCESS}
	fi
	return ${EXIT_CODE}
}
