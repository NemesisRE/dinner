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


function help {
	[[ ${1} ]] && local TASK=${1} && shift 1
	[[ ${1} ]] && local SUBTASK=${1} && shift 1
	if [[ ${SUBTASK} ]]; then
		extended_help ${TASK} ${SUBTASK}
		exit $EX_SUCCESS
	elif [[ ${TASK} ]]; then
		extended_help ${TASK}
		exit $EX_SUCCESS
	fi

printf "Dinner

Usage: dinner [options] TASK

Tasks:
dinner config [SUBTASK] [EXISTING FILE]            # Add an existing config from filesystem or create a new one
dinner make [SUBTASK] [CONFIG ..]                  # Clean a menu
dinner build [CONFIG ..]                            # Clone URI as a menu for dinner
dinner changelog [CONFIG ..]                       # Get changlog for config since last successfull build
dinner clearlogs [OLDER THAN x DAYS] [CONFIG ..]   # Clear logs
dinner pastelog [CONFIG] [LAST x LINES]            # Pastes latest error log for given config (last 300 lines by default, override by parameter)
dinner list                                        # List all menus
dinner update                                      # Updates dinner
dinner help [TASK]                                 # Show usage of a task

Runtime options:
-c, [--clean]      # Run make clean before starting brunch
-d, [--discard]    # Will add "-d" to SYNC_PARAMS of repo sync
-f, [--force-sync] # Force repo sync
-q, [--quiet]      # Quiet no output except errors (for cron)
-s, [--skip-sync]  # Skip sync
-v, [--verbose]    # Show full output

Note:
To clean or build all your configs
simply omit the CONFIG argument

"
}

function help_err {
	[[ ${1} ]] && local TASK=${1}
	[[ ${2} ]] && local SUBTASK=${2}
	if [[ ${SUBTASK} ]]; then
		extended_help ${TASK} ${SUBTASK}
		exit $EX_SUCCESS
	elif [[ ${TASK} ]]; then
		extended_help ${TASK}
		exit $EX_SUCCESS
	fi
}

function extended_help {
	[[ ${1} ]] && local TASK=${1}
	[[ ${2} ]] && local SUBTASK=${2}
	case ${TASK} in
		config)
			if [[ ${SUBTASK} ]]; then
				case ${SUBTASK} in
					add)
						printf "With this task you can add existing or generate new configs\n"
						printf "Usage:\n  dinner config add [NEWCONFIGNAME]"
						;;
					del)
						printf "With this task you can delete existing configs\n"
						printf "Usage:\n  dinner config del [CONFIGNAME]"
						;;
					edit)
						printf "With this task you can edit existing configs with your editor (${EDITOR:-vim})\n"
						printf "Usage:\n  dinner config edit [CONFIGNAME]"
						;;
					list)
						printf "Lists all available configs\n"
						printf "Usage:\n  dinner config list"
						;;
					show)
						printf "This will print all declared variables in the given config\n"
						printf "Usage:\n  dinner config show [CONFIGNAME]"
						;;
					*)
						printf "\"${SUBTASK}\" is not a subcommand of ${TASK} \n"
						printf "Subtasks: add | del | edit | list | show \n"
						printf "Usage:\n  dinner config [SUBTASK]"
						;;
				esac
			else
				printf "With this task you can do different things with your configs\n"
				printf "Subtasks: add | del | edit | list | show \n"
				printf "Usage:\n  dinner config [SUBTASK]"
			fi
			;;
		make)
			printf "Triggers \"make clean\" or \"make installclean\" for the given config(s)\n"
			printf "Usage:\n  dinner make [MAKE COMMAND] [CONFIG ..]"
			;;
		build)
			printf "builds a rom from the given config(s)\n"
			printf "Usage:\n  dinner build [CONFIG ..]"
			;;
		changelog)
			printf "Gets changelog for all given config(s), since last successfull build\n"
			printf "Usage:\n  dinner changelog [CONFIG ..]"
			;;
		clearlogs)
			printf "Clears the logs for all give config(s) which are older the the given time in days or 'all' for alltime\n"
			printf "Usage:\n  dinner clearlogs [ {0-9}+ | all ] [CONFIG ..]"
			;;
		pastelog)
			printf "Pastes latest error log for given config on https://paste.nrecom.net (last 300 lines by default, override by parameter)\n"
			printf "Usage:\n  dinner pastelog [CONFIG] [ NUMBER OF LINES ]"
			;;
		update)
			printf "Updates dinner\n"
			printf "Usage:\n  dinner update"
			;;
		help)
			printf "Shows usage of a task\n"
			printf "Usage:\n  dinner help [TASK] [SUBTASK]"
			;;
		*)	help;;
		esac
	printf "\n\n"
}
