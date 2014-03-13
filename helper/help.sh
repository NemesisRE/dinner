#!/bin/bash

function help {
	if [[ $1 ]]; then
		extended_help $1
		exit $EX_SUCCESS
	fi
printf "Dinner

Usage: dinner [options] TASK

 Tasks:
  dinner addconfig [EXISTING FILE]                   # Add an existing config from filesystem or create a new one
  dinner make [SUBTASK] [CONFIG ..]                  # Clean a menu
  dinner cook [CONFIG ..]                            # Clone URI as a menu for dinner
  dinner changelog [CONFIG ..]                       # Get changlog for config since last successfull build
  dinner clearlogs [OLDER THAN x DAYS] [CONFIG ..]   # Clear logs
  dinner list                                        # List all menus
  dinner update                                      # Updates dinner
  dinner help [TASK]                                 # Show usage of a task

 Runtime options:
   -c, [--clean]      # Run make clean before starting brunch
   -q, [--quiet]      # Quiet no output except errors (for cron)
   -s, [--skip-sync]  # Skip sync
   -v, [--verbose]    # Show full output

 Note:
  To clean or cook all your menus
  simply omit the MENU argument

"
}

function help_err {
	extended_help $1
	exit $EX_USAGE
}

function extended_help {
	case $1 in
		addconfig)
      printf "Add an existing config or create a new one \n"
      printf "Usage:\n  dinner addconfig [EXISTING FILE or CONFIG NAME]"
      ;;
		make)
      printf "Triggers \"make clean\" or \"make installclean\" for the given config(s)\n"
      printf "Usage:\n  dinner make [MAKE COMMAND] [CONFIG ..]"
      ;;
		cook)
      printf "builds a rom from the given config(s)\n"
      printf "Usage:\n  dinner cook [CONFIG ..]"
      ;;
		changelog)
      printf "Gets changelog for all given config(s), since last successfull build\n"
      printf "Usage:\n  dinner changelog [CONFIG ..]"
      ;;
		clearlogs)
      printf "Clears the logs for all give config(s) which are older the the given time in days or 'all' for alltime\n"
      printf "Usage:\n  dinner clearlogs [ {0-9}+ | all ] [CONFIG ..]"
      ;;
		list)
      printf "Lists all configs\n"
      printf "Usage:\n  dinner list"
      ;;
		update)
      printf "Updates dinner\n"
      printf "Usage:\n  dinner update"
      ;;
		help)
      printf "Shows usage of a task\n"
      printf "Usage:\n  dinner help [TASK]"
      ;;
		*)    help  ;;
		esac
	printf "\n\n"
}
