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

rm -f ${DINNER_TEMP_DIR}/*

trap "echo ""; _e_fatal \"Received SIGINT or SIGTERM\" ${EX_SIGTERM}" INT SIGINT SIGTERM

exit_status=$EX_SUCCESS

test -x $(which curl) && CURL_BIN=$(which curl) || _e_fatal "\"curl\" not found in PATH" $EX_SOFTWARE
if [ -x "${DINNER_DIR}/bin/repo" ]; then
	REPO_BIN=${DINNER_DIR}/bin/repo
elif [ -x "$(which repo)" ]; then
	REPO_BIN="$(which repo)"
else
	_exec_command "curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > ${DINNER_DIR}/bin/repo"
	if [ -e "${DINNER_DIR}/bin/repo" ]; then
		chmod a+x c
		REPO_BIN="${DINNER_DIR}/bin/repo"
	else
		_e_fatal "\"repo\" not found in PATH" $EX_SOFTWARE
	fi
fi
test -x $(which md5sum) && MD5_BIN=$(which md5sum) || _e_fatal "\"md5sum\" not found in PATH" $EX_SOFTWARE
test -x $(which mutt) && MAIL_BIN=$(which mutt) || _e_warning "\"mutt\" not found in PATH, will not send E-Mails..."
test -x ${DINNER_DIR}/bin/dinner_ansi2html.sh && ANSI2HTML_BIN=${DINNER_DIR}/bin/dinner_ansi2html.sh || _e_fatal "${DINNER_DIR}/bin/dinner_ansi2html.sh not executable" $EX_SOFTWARE

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
			-d)             SYNC_PARAMS+=" -d" ; shift; continue ;;
			-f | --force-sync) FORCE_SYNC=true ; shift; continue ;;
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
valid_commands=(config make pastelog clearlogs changelog cook update help)
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
			-d)             SYNC_PARAMS+=" -d" ; shift; continue ;;
			-f | --force-sync) FORCE_SYNC=true ; shift; continue ;;
			-h | --help)            cmd="help" ; shift; continue ;;
			-q | --quiet)     DINNER_CRON=true ; shift; continue ;;
			-v | --verbose)  SHOW_VERBOSE=true ; shift; continue ;;
			-s | --skip-sync)   SKIP_SYNC=true ; shift; continue ;;
			*)           _e_fatal "Unknown option '$1'" $EX_USAGE;;
		esac
	fi

	case $cmd in
		changelog | cook | pastelog)
			params+=("$1")
			shift; continue ;;
		make)
			[[ ! ${DINNER_MAKE} ]] && DINNER_MAKE="$1" || params+=("$1")
			shift; continue ;;
		clearlogs)
			[[ ! ${older_than} ]] && older_than="$1" || params+=("$1")
			shift; continue ;;
		update) _e_fatal "The 'update' command does not take any arguments" $EX_USAGE;;
		config)
			[[ ! ${sub_cmd} ]] && sub_cmd=$1 || params+=("$1")
			shift; continue;;
		help)
			[[ ! $help_cmd ]] && help_cmd=$1
			shift; continue;;
		*) _e_fatal "Unknown command '$1'" $EX_USAGE;;
	esac
done

# If no additional arguments are given, run the subcommand for every config
if [[ ! $params ]]; then
	case $cmd in
		changelog | cook | clearlogs | pastelog)
			while IFS= read -d $'\n' -r name ; do
				params+=("$name")
			done < <(_print_configs) ;;
		# These commands require parameters, show the help message instead
		config)
			case $sub_cmd in
				add | del | edit | show)
					help_cmd="$cmd $sub_cmd"; cmd="help"; exit_status=$EX_USAGE ;;
			esac
			;;
		make) help_cmd=$cmd; cmd="help"; exit_status=$EX_USAGE ;;
	esac
fi

case $cmd in
	config)
		case $sub_cmd in
			list) printf "${BLDWHT}%s${TXTDEF}\n" "Available Configs:" && _print_configs "\t\t%s\n" ;;
			*)
				for params in "${params[@]}"; do
					case $sub_cmd in
						add)
							_add_device_config "$params";;
						del)
							_del_device_config "$params";;
						edit)
							[[ $EDITOR ]] && $EDITOR "${DINNER_CONF_DIR}/${params}" || vi "${DINNER_CONF_DIR}/${params}";;
						show)
							cat "${DINNER_CONF_DIR}/${params}" | sed -e '/^#/ d' | awk -F# '{ print $1 }'| sed '/^\s*$/d' | sed 's/[ \t]*$//';;
					esac
				done
				;;
		esac
		;;
	update)    _dinner_update ;;
	help)      help $help_cmd ;;
	addconfig) _add_device_config ${NEW_CONFIG_NAME} ;;
	*)
		for params in "${params[@]}"; do
			case $cmd in
				make)         _run_config $cmd "${DINNER_MAKE}" "$params" ;;
				changelog)    _run_config $cmd "$params"                  ;;
				cook)         _run_config $cmd "$params"                  ;;
				clearlogs)    _clear_logs "$older_than" "$params"         ;;
				pastelog)     _find_last_errlog "$params"                 ;;
			esac
			echo " "
		done
		case $cmd in
			clearlogs) exit 0;;
			*)
				if ! ${CURRENT_CHANGELOG_ONLY} || ! ${CURRENT_MAKE_ONLY} ; then
					echo " "
					if [ ${DINNER_EXIT_CODE} == 0 ] && [ -z "${FAILED_CONFIGS}" ] && [ -z "${WARNING_CONFIGS}" ]; then
						_e_success "=== YEAH all configs finished sucessfull! ==="
						_e_success "These configs were successfull:" "${SUCCESS_CONFIGS}"
					else
						_e_error "=== DAMN something went wrong ==="
						if [ "${FAILED_CONFIGS}" ]; then
							_e_error "These configs failed:" "${FAILED_CONFIGS}"
						fi
						if [ "${WARNING_CONFIGS}" ]; then
							_e_warn "These configs had warnings:" "${WARNING_CONFIGS}"
						fi
						if [ "${SUCCESS_CONFIGS}" ]; then
							_e_success "These configs were successfull:" "${SUCCESS_CONFIGS}"
						fi
					fi
				fi
			;;
		esac
		;;
esac

exit ${DINNER_EXIT_CODE}
