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
		for line in "$@"; do
			printf "${STATUS_COLOR}%11b\t%b${txtdef}" " " "$line\n" 1>&2
		done
	fi
}

pending_status=''
pending_message=''
function _e_pending {
	pending_message="$1"
	printf "%10b:\t$bldcyn%b${txtdef}" "NOTICE" "$pending_message"
	sleep 3
}

function _e_notice () {
	if ! ${DINNER_CRON}; then
		_e "${bldwht}" "NOTICE" "$1"
	fi
}

function _e_pending_success () {
	[[ $1 ]] && pending_message=$1
	_e "\r\033[K${bldgrn}" "FINISHED" "${bldgrn}${pending_message}${txtdef}"
	unset pending_status pending_message
}

function _e_pending_skipped () {
	[[ $1 ]] && pending_message=$1
	_e "\r\033[K${bldblu}" "SKIPPING" "${bldblu}${pending_message}${txtdef}"
	unset pending_status pending_message
}

function _e_pending_warn () {
	[[ $1 ]] && pending_message=$1
	_e "\r\033[K${bldylw}" "WARNING" "${bldylw}${pending_message}${txtdef}"
	unset pending_status pending_message
}

function _e_pending_error () {
	[[ $1 ]] && pending_message=$1
	[[ ${2} ]] && local EXIT_CODE=${2} || local EXIT_CODE="1"
	_e "\r\033[K${bldylw}" "ERROR" "${bldred}${pending_message} (Exit Code ${EXIT_CODE})${txtdef}"
	unset pending_status pending_message
}

function _e_error () {
	_e "${bldred}" "ERROR" "${bldred}$1${txtdef}" 1>&2
}

function _e_fatal () {
	[[ ${2} ]] && local EXIT_CODE=${2} || local EXIT_CODE="1"
	_e "${bldpur}" "ABORT" "${bldpur}${1} (Exit Code ${EXIT_CODE})${txtdef}" "Stopping..." 1>&2
	exit ${EXIT_CODE}
}
