#!/bin/bash

# Define some colors
txtdef="\e[0m"    # Revert to default
bldred="\e[1;31m" # Red - error
bldgrn="\e[1;32m" # Green - success
bldylw="\e[1;33m" # Yellow - warning
bldpur="\e[1;35m" # Purple - fatal
bldwht="\e[1;37m" # White - info


function _e {
	if ! ${DINNER_CRON}; then
		printf "$1%20b${txtdef} %b\n" "\r$2" "$3"
	fi
}

pending_status=''
pending_message=''
function _e_pending {
	pending_status="$1"
	pending_message="$2"
	_e "$bldcyn" "$pending_message" "$pending_status"
}

function _e_notice () {
	if ! ${DINNER_CRON}; then
		_e "${bldwht}" "NOTICE:" "$1"
	fi
}

function _e_success () {
	[[ $1 ]] && pending_status=$1
	[[ $2 ]] && pending_message=$2
	printf "${bldwht}%20b${txtdef} %b" "${pending_status}" "${bldgrn}${pending_message}${txtdef}"
	unset pending_status pending_message
}

function _e_warning () {
	if [ ${2} ]; then
		_e "${bldylw}" "WARNING:" "$1 (Exit Code ${2})"
	else
		_e "${bldylw}" "WARNING:" "$1"
	fi
}

function _e_error () {
	_e "${bldred}" "ERROR:" "$1" 1>&2
}

function _e_fatal () {
	if [ ${2} ]; then
		_e "${bldpur}" "FATAL:" "${1} (Exit Code ${2})" "Stopping..." 1>&2
		exit ${2}
	else
		_e "${bldpur}" "FATAL:" "${1} (Exit Code 1)" "Stopping..." 1>&2
		exit 1
	fi
}
