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

#set -e 	#do not enable otherwise brunch will fail
#set -x

DINNER_DIR="$( cd $( dirname ${0} )/.. && pwd )"
DINNER_CONF_DIR="${DINNER_DIR}/config.d"
DINNER_LOG_DIR="${DINNER_DIR}/logs"
DINNER_MEM_DIR="${DINNER_DIR}/memory"
DINNER_TEMP_DIR="${DINNER_DIR}/tmp"

source ${DINNER_CONF_DIR}/DINNER_DEFAULTS
source ${DINNER_DIR}/helper/dinner_functions.sh
source ${DINNER_DIR}/helper/log.sh
source ${DINNER_DIR}/helper/help.sh
source ${DINNER_DIR}/helper/exit_status.sh

trap "echo ""; _e_fatal \"Received SIGINT or SIGTERM\" ${EX_SIGTERM}" INT SIGINT SIGTERM

exit_status=$EX_SUCCESS

test -x $(which repo) && REPO_BIN=$(which repo) || _e_fatal "repo not found in path" $EX_SOFTWARE
test -x $(which md5sum) && MD5_BIN=$(which md5sum) || _e_fatal "md5sum not found in path" $EX_SOFTWARE
test -x $(which mutt) && MAIL_BIN=$(which mutt) || _e_warning "Mutt not found, will not send E-Mails..."
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
			-c | --clean)  DINNER_MAKE="clean" ; shift; continue ;;
			-h | --help)            cmd="help" ; shift; continue ;;
			-q | --quiet)     DINNER_CRON=true ; shift; continue ;;
			-v | --verbose)  SHOW_VERBOSE=true ; shift; continue ;;
			-s | --skip-sync)   SKIP_SYNC=true ; shift; continue ;;
			*)           _e_fatal "Unknown option '$1'" $EX_USAGE;;
		esac
	else
		break
	fi
done

[[ $# -gt 0 ]] || cmd="help"

# Get the subcommand
valid_commands=(make clearlogs changelog cook list update help)
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
			-c | --clean)  DINNER_MAKE="clean" ; shift; continue ;;
			-h | --help)            cmd="help" ; shift; continue ;;
			-q | --quiet)     DINNER_CRON=true ; shift; continue ;;
			-v | --verbose)  SHOW_VERBOSE=true ; shift; continue ;;
			-s | --skip-sync)   SKIP_SYNC=true ; shift; continue ;;
			*)           _e_fatal "Unknown option '$1'" $EX_USAGE;;
		esac
	fi

	case $cmd in
		changelog | cook)
			params+=("$1")
			shift; continue ;;
		make)
			[[ ! ${DINNER_MAKE} ]] && DINNER_MAKE="$1" || params+=("$1")
			shift; continue ;;
		clearlogs)
			[[ ! ${older_than} ]] && older_than="$1" || params+=("$1")
			shift; continue ;;
		list) _e_fatal "The 'list' command does not take any arguments" $EX_USAGE;;
		update) _e_fatal "The 'update' command does not take any arguments" $EX_USAGE;;
		help)
			[[ ! $help_cmd ]] && help_cmd=$1
			shift; continue;;
		*) _e_fatal "Unknown command '$1'" $EX_USAGE;;
	esac
done

# If no additional arguments are given, run the subcommand for every config
if [[ ! $params ]]; then
	case $cmd in
		changelog | cook | clearlogs)
			while IFS= read -d $'\n' -r name ; do
				params+=("$name")
			done < <(_print_configs) ;;
		# These commands require parameters, show the help message instead
		make) help_cmd=$cmd; cmd="help"; exit_status=$EX_USAGE ;;
	esac
fi

case $cmd in
	list)   printf "${BLDWHT}%s${TXTDEF}\n" "Available Configs:" && _print_configs "\t\t%s\n" ;;
	update) _dinner_update ;;
	help)   help $help_cmd ;;
	*)
		for params in "${params[@]}"; do
			case $cmd in
				make)         _run_config $cmd "${DINNER_MAKE}" "$params" ;;
				changelog)    _run_config $cmd "$params"                  ;;
				cook)         _run_config $cmd "$params"                  ;;
				clearlogs)    _clear_logs "$older_than" "$params"         ;;
			esac
		done
		case $cmd in
			clearlogs) exit 0;;
			*)
				if ${CURRENT_CHANGELOG_ONLY} || ; then
					exit 0
				fi
				echo " "
				if [ ${DINNER_EXIT_CODE} == 0 ] && [ -z "${FAILED_CONFIGS}" ] && [ -z "${WARNING_CONFIGS}" ]; then
					_e "${BLDGRN}" "SUCCESS" "=== YEAH all configs finished sucessfull! ==="
					_e "${BLDGRN}" "SUCCESS" "These configs were successfull:" "${SUCCESS_CONFIGS}"
					exit 0
				else
					_e_error "=== DAMN something went wrong ==="
					if [ "${FAILED_CONFIGS}" ]; then
						_e_error "These configs failed:" "NULL" "${FAILED_CONFIGS}"
					fi
					if [ "${WARNING_CONFIGS}" ]; then
						_e_error "These configs had warnings:" "NULL" "${WARNING_CONFIGS}"
					fi
					if [ "${SUCCESS_CONFIGS}" ]; then
						_e "${BLDGRN}" "SUCCESS" "These configs were successfull:" "${SUCCESS_CONFIGS}"
					fi
					_e_fatal "Script will exit with overall exit code" "${DINNER_EXIT_CODE}"
				fi
			;;
		esac
		;;
esac

exit ${DINNER_EXIT_CODE}
