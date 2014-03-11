#!/bin/bash

# Define some colors
txtdef="\e[0m"    # Revert to default
bldred="\e[1;31m" # Red - error
bldgrn="\e[1;32m" # Green - success
bldylw="\e[1;33m" # Yellow - warning
bldblu="\e[1;34m" # Blue - no action/ignored
bldpur="\e[1;35m" # Purple - fatal
bldcyn="\e[1;36m" # Cyan - pending
bldwht="\e[1;37m" # White - notice


function _e {
	local STATUS_COLOR=${1}
	local STATUS_NAME=${2}
	local STATUS_MESSAGE=${3}
	shift 3
	if ! ${DINNER_CRON:-"false"}; then
		printf "${STATUS_COLOR}%10b:\t%b\n${txtdef}" "${STATUS_NAME}" "${STATUS_MESSAGE}"
		printf "%13b:\t%b\n" "${STATUS_NAME}" "${STATUS_MESSAGE}" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner_general.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_general_error.log} )

		for line in "$@"; do
			printf "${STATUS_COLOR}%11b\t%b${txtdef}" " " "$line\n"
			printf "%11b\t%b" " " "$line\n" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner_general.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_general_error.log} )
		done
	fi
}

pending_status=''
pending_message=''
function _e_pending {
	if ! ${DINNER_CRON:-"false"}; then
		[[ ${1} ]] && pending_message=${1}
		printf "${bldcyn}%10b:\t%b${txtdef}" "RUNNING" "$pending_message"
		printf "%13b:\t%b\n" "RUNNING" "$pending_message"  | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" &> /dev/null > >( tee -a ${CURRENT_LOG:-${DINNER_LOG_DIR}/dinner_general.log} ${CURRENT_ERRLOG:-${DINNER_LOG_DIR}/dinner_general_error.log} )
		sleep 3
	fi
}

function _e_notice () {
	_e "${bldwht}" "NOTICE" "${1}"
}

function _e_pending_success () {
	unset pending_message
	[[ ${1} ]] && pending_message=${1}
	_e "\r\033[K${bldgrn}" "FINISHED" "${pending_message}"

}

function _e_pending_skipped () {
	unset pending_message
	[[ ${1} ]] && pending_message=${1}
	_e "\r\033[K${bldblu}" "SKIPPED" "${pending_message}"
}

function _e_pending_warn () {
	unset pending_message
	[[ ${1} ]] && pending_message=${1}
	_e "\r\033[K${bldylw}" "WARNING" "${pending_message}"
}

function _e_pending_error () {
	unset pending_message EXIT_CODE
	[[ ${1} ]] && pending_message=${1}
	[[ ${2} ]] && [[ ${2} =~ ^[0-9]+$ ]] && local EXIT_CODE="(Exit Code ${2})"
	_e "\r\033[K${bldred}" "ERROR" "${pending_message} ${EXIT_CODE}"
}

function _e_pending_fatal () {
	unset pending_message EXIT_CODE
	[[ ${1} ]] && pending_message=${1}
	[[ ${2} ]] && [[ ${2} =~ ^[0-9]+$ ]] && local EXIT_CODE="(Exit Code ${2})"
	_e "\r\033[K${bldpur}" "ABORT" "${pending_message} ${EXIT_CODE}" "Stopping..."
	exit ${2:-1}
}

function _e_error () {
	unset EXIT_MESSAGE EXIT_CODE ERROR_MESSAGE
	[[ ${1} ]] && local EXIT_MESSAGE=${1}
	[[ ${2} ]] && [[ ${2} =~ ^[0-9]+$ ]] && local EXIT_CODE="(Exit Code ${2})" && shift 2 || shift 1
	_e "${bldred}" "ERROR" "${EXIT_MESSAGE} ${EXIT_CODE}" ${@}
}

function _e_fatal () {
	unset EXIT_MESSAGE EXIT_CODE
	[[ ${1} ]] && local EXIT_MESSAGE=${1}
	[[ ${2} ]] && [[ ${2} =~ ^[0-9]+$ ]] && local EXIT_CODE="(Exit Code ${2})"
	_e "${bldpur}" "ABORT" "${EXIT_MESSAGE} ${EXIT_CODE}" "Stopping..."
	exit ${2:-1}
}
