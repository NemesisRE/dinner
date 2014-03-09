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
	if ! ${DINNER_CRON}; then
		printf "${STATUS_COLOR}%10b:${txtdef}\t%b\n" "${STATUS_NAME}" "${STATUS_MESSAGE}"
		printf "%b:\t%b\n" "${STATUS_NAME}" "${STATUS_MESSAGE}" &>> ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log
		for line in "$@"; do
			printf "${STATUS_COLOR}%11b\t%b${txtdef}" " " "$line\n"
			printf "%11b\t%b" " " "$line\n" &>> ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log
		done
	fi
}

pending_status=''
pending_message=''
function _e_pending {
	if ! ${DINNER_CRON}; then
		pending_message="${1}"
		printf "${bldcyn}%10b:${txtdef}\t${bldcyn}%b${txtdef}" "RUNNING" "$pending_message"
		sleep 3
	fi
}

function _e_notice () {
	_e "${bldwht}" "NOTICE" "${1}"
}

function _e_pending_success () {
	[[ ${1} ]] && pending_message=${1}
	_e "\r\033[K${bldgrn}" "FINISHED" "${bldgrn}${pending_message}${txtdef}"
	unset pending_status pending_message
}

function _e_pending_skipped () {
	[[ ${1} ]] && pending_message=${1}
	_e "\r\033[K${bldblu}" "SKIPED" "${bldblu}${pending_message}${txtdef}"
	unset pending_status pending_message
}

function _e_pending_warn () {
	[[ ${1} ]] && pending_message=${1}
	_e "\r\033[K${bldylw}" "WARNING" "${bldylw}${pending_message}${txtdef}"
	unset pending_status pending_message
}

function _e_pending_error () {
	[[ ${1} ]] && pending_message=${1}
	[[ ${2} ]] && [[ ${2} =~ ^[0-9]+$ ]] && local EXIT_CODE="(Exit Code ${2})"
	_e "\r\033[K${bldred}" "ERROR" "${bldred}${pending_message} ${EXIT_CODE}${txtdef}"
	unset pending_status pending_message
}

function _e_error () {
	[[ ${1} ]] && local EXIT_MESSAGE=${1}
	[[ ${2} ]] && [[ ${2} =~ ^[0-9]+$ ]] && local EXIT_CODE="(Exit Code ${2})"
	[[ ${3} ]] && local ERROR_MESSAGE="${3}"
	_e "${bldred}" "ERROR" "${bldred}${EXIT_MESSAGE} ${EXIT_CODE}${txtdef}" ${3}
}

function _e_fatal () {
	[[ ${2} ]] && local EXIT_CODE=${2} || local EXIT_CODE="1"
	_e "${bldpur}" "ABORT" "${bldpur}${1} (Exit Code ${EXIT_CODE})${txtdef}" "Stopping..."
	exit ${EXIT_CODE}
}
