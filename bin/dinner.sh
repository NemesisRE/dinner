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

DINNER_DIR="$( cd $( dirname ${0} )/.. && pwd )"

source ${DINNER_DIR}/helper/dinner_defaults.sh
source ${DINNER_DIR}/helper/dinner_functions.sh
source ${DINNER_DIR}/helper/log.sh
source ${DINNER_DIR}/helper/help.sh
source ${DINNER_DIR}/helper/exit_status.sh

trap "echo ""; _e_fatal \"Received SIGINT or SIGTERM\" ${EX_SIGTERM}" SIGINT SIGTERM

exit_status=$EX_SUCCESS

test -x $(which repo) && REPO_BIN=$(which repo) || _e_fatal "repo not found in path" $EX_SOFTWARE
test -x $(which mail) && MAIL_BIN=$(which mail) || _e_fatal "mail not found in path" $EX_SOFTWARE
test -x ${DINNER_DIR}/bin/dinner_ansi2html.sh && ANSI2HTML_BIN=${DINNER_DIR}/bin/dinner_ansi2html.sh || _e_fatal " not found in path" $EX_SOFTWARE

# Retrieve all the flags preceeding a subcommand
while [[ $# -gt 0 ]]; do
	if [[ $1 =~ ^- ]]; then
		# Convert combined short options into multiples short options (e.g. `-qb' to `-q -b')
		if [[ $1 =~ ^-[a-z]{2,} ]]; then
			param=$1
			shift
			set -- ${param:0:2} -${param:2} $@
			unset param
		fi
		case $1 in
			-c | --cron)      DINNER_CRON=true ; shift; continue ;;
			-h | --help)            cmd="help" ; shift; continue ;;
			-v | --verbose) SHOW_VERBOSE=true  ; shift; continue ;;
			-s | --skip)            SKIP=true  ; shift; continue ;;
			*)           _e_fatal "Unknown option '$1'" $EX_USAGE;;
		esac
	else
		break
	fi
done

[[ $# -gt 0 ]] || cmd="help"

# Get the subcommand
valid_commands=(clean changelog cook list help)
if [[ ! $cmd ]]; then
	if [[ " ${valid_commands[*]} " =~ " $1 " ]]; then
		cmd=$1
		shift
	fi
	if [[ ! $cmd ]]; then
		_e_fatal "Unknown command '$1'" $EX_USAGE
	fi
fi

# Get the arguments for the subcommand, also parse flags if there are any left
while [[ $# -gt 0 ]]; do
	if [[ $1 =~ ^- ]]; then
		# Convert combined short options into multiples short options (e.g. `-qb' to `-q -b')
		if [[ $1 =~ ^-[a-z]{2,} ]]; then
			param=$1
			shift
			set -- ${param:0:2} -${param:2} $@
			unset param
		fi
		case $1 in
			-c | --cron)      DINNER_CRON=true ; shift; continue ;;
			-h | --help)            cmd="help" ; shift; continue ;;
			-v | --verbose) SHOW_VERBOSE=true  ; shift; continue ;;
			-s | --skip)       SKIP_SYNC=true  ; shift; continue ;;
			*)           _e_fatal "Unknown option '$1'" $EX_USAGE;;
		esac
	fi

	case $cmd in
		clean | changelog | cook)
			params+=("$1")
			shift; continue ;;
		list) _e_fatal "The 'list' command does not take any arguments" $EX_USAGE;;
		help)
			[[ ! $help_cmd ]] && help_cmd=$1
			shift; continue;;
		*) _e_fatal "Unknown command '$1'" $EX_USAGE;;
	esac
done

# If no additional arguments are given, run the subcommand for every config
if [[ ! $params ]]; then
	case $cmd in
		clean | changelog | cook)
			while IFS= read -d $'\n' -r name ; do
				params+=("$name")
			done < <(_print_configs) ;;
		# These commands require parameters, show the help message instead
		# none) help_cmd=$cmd; cmd="help"; exit_status=$EX_USAGE ;;
	esac
fi

case $cmd in
	list)  _list_configs           ;;
	help)  help $help_cmd ;;
	*)
		for params in "${params[@]}"; do
			case $cmd in
				clean)         _run_config $params clean          ;;
				changelog)     _run_config $params changelog      ;;
				cook)          _run_config $params                ;;
			esac
		done
		if [ ${OVERALL_EXIT_CODE} == 0 ] && [ -z "${FAILED_CONFIGS}" ] && [ -z "${WARNING_CONFIGS}" ]; then
			_e_notice "=== YEAH all configs finished sucessfull! ==="
			_e_notice "These configs were successfull: ${SUCCESS_CONFIGS}"
			exit 0
		else
			_e_error "=== DAMN something went wrong ==="
			if [ "${FAILED_CONFIGS}" ]; then
				_e_error "These configs failed: ${FAILED_CONFIGS}"
			fi
			if [ "${WARNING_CONFIGS}" ]; then
				_e_error "These configs had warnings: ${WARNING_CONFIGS}"
			fi
			if [ "${SUCCESS_CONFIGS}" ]; then
				_e_notice "These configs were successfull: ${SUCCESS_CONFIGS}"
			fi
			_e_fatal "Script will exit with overall exit code" "${OVERALL_EXIT_CODE}"
		fi
		;;
esac

exit $exit_status
