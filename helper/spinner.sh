#!/bin/bash

# Author: Tasos Latsas

# spinner.sh
#
# Display an awesome 'spinner' while running your long shell commands
#
# Do *NOT* call _spinner function directly.
# Use {start,stop}_spinner wrapper functions

# usage:
#   1. source this script in your's
#   2. start the spinner:
#       start_spinner
#   3. run your command
#   4. stop the spinner:
#       stop_spinner
#
# Also see: test.sh


function _spinner() {
	# $1 start/stop
	#
	# on start: $2 display message
	# on stop : $2 process exit status
	#           $3 spinner function pid (supplied from stop_spinner)

	case $1 in
		start)
			# calculate the column where spinner and status msg will be displayed
			let column=$(tput cols)-${#2}-8
			# display message and position the cursor in $column column
			printf "%${column}s"

			# start spinner
			i=1
			sp='\|/-'
			delay=0.15

			while :
			do
				printf "\b${sp:i++%${#sp}:1}"
				sleep $delay
			done
			;;
		stop)
			if [[ -z ${3} ]]; then
				echo "spinner is not running.."
				exit 1
			fi

			kill $2 > /dev/null 2>&1

			return ${2}
			;;
		*)
			echo "invalid argument, try {start/stop}"
			exit 1
			;;
	esac
}

function _start_spinner {
	# $1 : msg to display
	_spinner "start" &
	# set global spinner pid
	_sp_pid=$!
	disown
}

function _stop_spinner {
	# $1 : command exit status
	_spinner "stop" $? $_sp_pid
	unset _sp_pid
}

