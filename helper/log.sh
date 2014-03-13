#!/bin/bash

# Define some colors
TXTDEF="\e[0m"    # Revert to default
BLDRED="\e[1;31m" # Red - error
BLDGRN="\e[1;32m" # Green - success
BLDYLW="\e[1;33m" # Yellow - warning
BLDBLU="\e[1;34m" # Blue - no action/ignored
BLDPUR="\e[1;35m" # Purple - fatal
BLDCYN="\e[1;36m" # Cyan - pending
BLDWHT="\e[1;37m" # White - notice


function _e {
	unset STATUS_COLOR STATUS_NAME STATUS_MESSAGE
	local STATUS_COLOR=${1}
	local STATUS_NAME=${2}
	local STATUS_MESSAGE=${3}
	shift 3
	if ! ${DINNER_CRON:-"false"}; then
		printf "${STATUS_COLOR}%10b:\t%b\n${TXTDEF}" "${STATUS_NAME}" "${STATUS_MESSAGE}"
		printf "%13b:\t%b\n" "${STATUS_NAME}" "${STATUS_MESSAGE}" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner_general.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_general_error.log} )

		for LINE in "$@"; do
			printf "${STATUS_COLOR}%11b\t%b${TXTDEF}" " " "${LINE}\n"
			printf "%11b\t%b" " " "${LINE}\n" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner_general.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_general_error.log} )
		done
	fi
}

function _e_pending {
	if ! ${DINNER_CRON:-"false"}; then
		unset PENDING_MESSAGE
		[[ ${1} ]] && local PENDING_MESSAGE=${1}
		printf "${BLDCYN}%10b:\t%b${TXTDEF}" "RUNNING" "$PENDING_MESSAGE"
		printf "%13b:\t%b\n" "RUNNING" "$PENDING_MESSAGE"  | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner_general.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_general_error.log} )
		sleep 3
	fi
}

function _e_pending_notice () {
	unset PENDING_SUCCESS_MESSAGE
	[[ ${1} ]] && local PENDING_NOTICE_MESSAGE=${1}
	shift 1
	_e "\r\033[K${BLDWHT}" "NOTICE" "${PENDING_NOTICE_MESSAGE}" "${@}"
}

function _e_pending_success () {
	unset PENDING_SUCCESS_MESSAGE
	[[ ${1} ]] && PENDING_SUCCESS_MESSAGE=${1}
	shift 1
	_e "\r\033[K${BLDGRN}" "FINISHED" "${PENDING_SUCCESS_MESSAGE}" "${@}"

}

function _e_pending_skipped () {
	unset PENDING_SKIPPED_MESSAGE
	[[ ${1} ]] && PENDING_SKIPPED_MESSAGE=${1}
	shift 1
	_e "\r\033[K${BLDBLU}" "SKIPPED" "${PENDING_SKIPPED_MESSAGE}" "${@}"
}

function _e_pending_warn () {
	unset PENDING_WARN_MESSAGE
	[[ ${1} ]] && PENDING_WARN_MESSAGE=${1}
	shift 1
	_e "\r\033[K${BLDYLW}" "WARNING" "${PENDING_WARN_MESSAGE}" "${@}"
}

function _e_pending_error () {
	unset PENDING_ERROR_MESSAGE EXIT_CODE
	[[ ${1} ]] && PENDING_ERROR_MESSAGE=${1}
	[[ ${2} ]] && [[ ${2} =~ ^[0-9]+$ ]] && local EXIT_CODE="(Exit Code ${2})" && shift 2 || shift 1
	_e "\r\033[K${BLDRED}" "ERROR" "${PENDING_ERROR_MESSAGE} ${EXIT_CODE}" "${@}"
}

function _e_pending_fatal () {
	unset PENDING_FATAL_MESSAGE EXIT_CODE
	[[ ${1} ]] && PENDING_FATAL_MESSAGE=${1}
	[[ ${2} ]] && [[ ${2} =~ ^[0-9]+$ ]] && local EXIT_CODE="(Exit Code ${2})" && shift 2 || shift 1
	_e "\r\033[K${BLDPUR}" "ABORT" "${PENDING_FATAL_MESSAGE} ${EXIT_CODE}" "Stopping..." "${@}"
	exit ${2:-1}
}

function _e_notice () {
	unset NOTICE_MESSAGE
	[[ ${1} ]] && local NOTICE_MESSAGE=${1}
	_e "${BLDWHT}" "NOTICE" "${NOTICE_MESSAGE}"
}

function _e_success () {
	unset SUCCESS_MESSAGE
	[[ ${1} ]] && local SUCCESS_MESSAGE=${1}
	_e "${BLDGRN}" "FINISHED" "${SUCCESS_MESSAGE}"
}

function _e_warn () {
	unset WARN_MESSAGE
	[[ ${1} ]] && local WARN_MESSAGE=${1}
	_e "${BLDYLW}" "WARNING" "${WARN_MESSAGE}"
}

function _e_error () {
	unset EXIT_MESSAGE EXIT_CODE ERROR_MESSAGE
	[[ ${1} ]] && local ERROR_MESSAGE=${1}
	[[ ${2} ]] && [[ ${2} =~ ^[0-9]+$ ]] && local EXIT_CODE="(Exit Code ${2})"
	shift 2
	_e "${BLDRED}" "ERROR" "${ERROR_MESSAGE} ${EXIT_CODE}" "${@}"
}

function _e_fatal () {
	unset EXIT_MESSAGE EXIT_CODE
	[[ ${1} ]] && local FATAL_MESSAGE=${1}
	[[ ${2} ]] && [[ ${2} =~ ^[0-9]+$ ]] && local EXIT_CODE="(Exit Code ${2})"
	_e "${BLDPUR}" "ABORT" "${FATAL_MESSAGE} ${EXIT_CODE}" "Stopping..."
	exit ${2:-1}
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
	if ${SHOW_VERBOSE:-"false"}; then
		# log STDOUT and STDERR, send both to STDOUT
		_e "\n${BLDYLW}" "COMMAND" "${COMMAND}"
		eval "${COMMAND} 2> >(tee -a ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_general_error.log}) &>>(tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner_general.log})"
	else
		# log STDOUT and STDERR but send only STDERR to STDOUT
		printf "%13b:\t%b\n" "COMMAND" "${COMMAND}" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner_general.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_general_error.log} )
		eval "${COMMAND} 2>>${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_general_error.log} &>>${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner_general.log}"
	fi
	local EXIT_CODE=${?}
	printf "%13b:\t%b\n" "EXIT CODE" "${EXIT_CODE}" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner_general.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_general_error.log} )
	if [ "${EXIT_CODE}" != 0 ] && [ "${FAIL}" != "NOTSET" ]; then
		eval ${FAIL} ${EXIT_CODE}
	elif [ "${SUCCESS}" != "NOTSET" ]; then
		eval ${SUCCESS}
	fi
	return ${EXIT_CODE}
}
