#!/bin/bash

# Define some colors
txtdef="\e[0m"    # Revert to default
bldred="\e[1;31m" # Red - error
bldgrn="\e[1;32m" # Green - success
bldylw="\e[1;33m" # Yellow - warning
bldpur="\e[1;35m" # Purple - fatal
bldwht="\e[1;37m" # White - info


function _e_notice () {
	if ! ${DINNER_CRON}; then
		printf "${bldwht}\t%s${txtdef} %s\n" "NOTICE:" "$1"
	fi
}

function _e_warning () {
	if [ ${2} ]; then
		printf "${bldylw}\t%s${txtdef} %s\n" "WARNING:" "$1 (Exit Code ${2}"
	else
		printf "${bldylw}\t%s${txtdef} %s\n" "WARNING:" "$1"
	fi
}

function _e_error () {
	printf "${bldred}\t%s${txtdef} %s\n" "ERROR:" "$1" 1>&2
}

function _e_fatal () {
	if [ ${2} ]; then
		printf "${bldpur}\t%s${txtdef} %s\n" "FATAL:" "${1} (Exit Code ${2})" "Stopping..." 1>&2
		exit ${2}
	else
		printf "${bldpur}\t%s${txtdef} %s\n" "FATAL:" "${1} (Exit Code 1)" "Stopping..." 1>&2
		exit 1
	fi
}
