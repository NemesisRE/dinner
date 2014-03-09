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
		printf "$1%b$txtdef %b\n" "$2" "$3"
	fi
}

function _e_notice () {
	if ! ${DINNER_CRON}; then
		_e "${bldwht}" "NOTICE:\t" "$1"
	fi
}

function _e_success () {
		_e "${bldwht}" "NOTICE:\t" "${bldgrn}$1${txtdef}"
}

function _e_warning () {
	if [ ${2} ]; then
		printf "${bldylw}%b${txtdef} \t %b\n" "WARNING:" "$1 (Exit Code ${2})"
	else
		printf "${bldylw}%b${txtdef} \t %b\n" "WARNING:" "$1"
	fi
}

function _e_error () {
	_e "${bldred}" "ERROR:\t\t" "$1" 1>&2
}

function _e_fatal () {
	if [ ${2} ]; then
		_e "${bldpur}" "FATAL:\t\t" "${1} (Exit Code ${2})" "Stopping..." 1>&2
		exit ${2}
	else
		_e "${bldpur}" "FATAL:\t\t" "${1} (Exit Code 1)" "Stopping..." 1>&2
		exit 1
	fi
}
