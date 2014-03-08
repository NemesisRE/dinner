#!/bin/bash

function help {
	if [[ $1 ]]; then
		extended_help $1
		exit $EX_SUCCESS
	fi
printf "Dinner

Usage: dinner [options] TASK

 Tasks:
  dinner clean MENU                # Clean a menu
  dinner cook MENU                 # Clone URI as a menu for dinner
  dinner list                      # List all menus
  dinner update                    # Updates dinner
  dinner help [TASK]               # Show usage of a task

 Runtime options:
   -v, [--verbose]    # Show full output
   -s, [--skip]       # Skip sync

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
		clean)
      printf "Triggers \"make clean\" or \"make installclean\" for the given menu(s)\n"
      printf "Usage:\n  dinner clean [MAKE_COMMAND] [MENU ..]"
      ;;
		cook)
      printf "builds a rom from the given menu(s)\n"
      printf "Usage:\n  dinner cook [MENU ..]"
      ;;
		list)
      printf "Lists all menus\n"
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
