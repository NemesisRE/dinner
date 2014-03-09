#!/bin/bash

##
# _exec_command
#
# param1 = command
# param2 = Fail command
# param3 = Success command
#
function _exec_command () {
	local COMMAND=${1}
	local FAIL=${2:NOTSET}
	local SUCCESS=${3:NOTSET}
	if ${SHOW_VERBOSE}; then
		# log STDOUT and STDERR, send both to STDOUT
		eval "${COMMAND} &> >(tee -a ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log)"
	else
		# log STDOUT and STDERR but send only STDERR to STDOUT
		eval "${COMMAND} &>> ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log"
	fi
	local EXIT_CODE=${?}
	if [ "${EXIT_CODE}" != 0 ] && [ "${FAIL}" != "NOTSET" ]; then
		eval ${FAIL} ${EXIT_CODE}
	elif [ "${SUCCESS}" != "NOTSET" ]; then
		eval ${SUCCESS}
	fi
	return ${EXIT_CODE}
}

function _dinner_update () {
	_e_pending "Checking for updates"
cd ${DINNER_DIR} && DINNER_UPDATES=$($(which git) fetch --dry-run --no-progress 2>/dev/null)
	cd ${DINNER_DIR} && GIT_MESSAGE=$($(which git) pull --no-stat --no-progress | head -1 2>/dev/null)
	DINNER_UPDATE_EXIT_CODE=${?}
	if [ "${DINNER_UPDATE_EXIT_CODE}" == "0" ]; then
		_e_success "${GIT_MESSAGE}       "
		for line in "${DINNER_UPDATES}"; do
			printf "                    $line\n" >&2
		done
		if [ "${GIT_MESSAGE}" != "Already up-to-date." ]; then
			_e_notice "Restart your Shell or run: \"source ${DINNER_DIR}/dinner.sh\""
		fi
	else
		_e_fail "${GIT_MESSAGE}"
	fi
}


function _generate_user_message () {
	echo -e "${1}" >> "${DINNER_TEMP_DIR}/mail_user_message_${CURRENT_CONFIG}.txt"
}

function _generate_admin_message () {
	echo -e "${1}" >> "${DINNER_TEMP_DIR}/mail_admin_message_${CURRENT_CONFIG}.txt"
}

function _check_prerequisites () {
	if [ -f "${DINNER_DIR}/config.d/${CURRENT_CONFIG}" ]; then
		source ${DINNER_DIR}/config.d/${CURRENT_CONFIG}
	else
		_e_fatal "Config \"${CURRENT_CONFIG}\" not found!"
	fi

	_check_variables

	_source_envsetup

	if [ -x ${REPO_DIR}/vendor/cm/get-prebuilts ]; then
		_exec_command "${REPO_DIR}/vendor/cm/get-prebuilts"
	fi

	_set_current_variables

	cd "${REPO_DIR}"

	_e_notice "Starting work on config \"${CURRENT_CONFIG}\"..."
}

function _source_envsetup () {
	if [ ! -d "${REPO_DIR}/.repo" ]; then
		_e_fatal "${REPO_DIR} is not a Repo!"
	elif [ -f "${REPO_DIR}/build/envsetup.sh" ]; then
		_exec_command ". ${REPO_DIR}/build/envsetup.sh"
	else
		_e_fatal "${REPO_DIR}/build/envsetup.sh could not be found."
	fi
}

function _set_current_variables () {
	#Set initial exitcodes
	OVERALL_EXIT_CODE=0
	CURRENT_BUILD_SKIPPED=false
	CURRENT_SYNC_REPO_EXIT_CODE=0
	CURRENT_BUILD_STATUS=false
	CURRENT_CONFIG_EXIT_CODE=0
	CURRENT_BRUNCH_DEVICE_EXIT_CODE=0
	CURRENT_MOVE_BUILD_EXIT_CODE=0
	CURRENT_PRE_BUILD_COMMAND_EXIT_CODE=0
	CURRENT_POST_BUILD_COMMAND_EXIT_CODE=0
	CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=0
	CURRENT_SEND_MAIL_EXIT_CODE=0
	CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE=0

	#Set current config Variables
	eval CURRENT_REPO_NAME=$(echo ${REPO_DIR} | sed 's/\//_/g')
	eval CURRENT_REPOPICK="\"${REPOPICK}\""
	eval CURRENT_DEVICE="${BUILD_FOR_DEVICE}"
	eval CURRENT_PRE_BUILD_COMMAND="${PRE_BUILD_COMMAND}"
	eval CURRENT_POST_BUILD_COMMAND="${POST_BUILD_COMMAND}"
	eval CURRENT_TARGET_DIR="${TARGET_DIR}"
	eval CURRENT_CLEANUP_OLDER_THAN="${CLEANUP_OLDER_THAN}"
	eval CURRENT_MAIL="${MAIL}"
	eval CURRENT_ADMIN_MAIL="${ADMIN_MAIL}"
	eval CURRENT_DOWNLOAD_LINK="${DOWNLOAD_LINK}"
	eval CURRENT_LOG_TIME="$(date +%Y%m%d-%H%M)"
	eval CURRENT_STATUS="failed"
	[[ $CURRENT_CHANGELOG_ONLY ]] && CURRENT_CHANGELOG_ONLY="true" || CURRENT_CHANGELOG_ONLY="false"
	[[ $CURRENT_CLEAN_ONLY ]] && CURRENT_CLEAN_ONLY="true" || CURRENT_CLEAN_ONLY="false"
}

function _check_variables () {
	# Check essentials
	if [ ! ${REPO_BIN} ] || [ ! -x ${REPO_BIN} ]; then
		_e_fatal "Repo binary (${REPO_BIN}) is not found or not executable!"
	fi

	if [ ! "${REPO_DIR}" ]; then
		_e_fatal "REPO_DIR is not set!"
	elif [ ! ${BUILD_FOR_DEVICE} ]; then
		_e_fatal "No Device given! Stopping..."
	fi

	if [ ! ${SKIP_SYNC_TIME} ] || [ -z ${SKIP_SYNC_TIME##*[!0-9]*} ]; then
		_e_error "SKIP_SYNC_TIME has no valid number or is not set, will use default (600)!"
		SKIP_SYNC_TIME="1800"
	fi

	if [ ${DINNER_USE_CCACHE} ] && [[ "${DINNER_USE_CCACHE}" =~ "^{0,1}$" ]]; then
		export USE_CCACHE=${DINNER_USE_CCACHE}
	fi

	if [ ${DINNER_CCACHE_DIR} ]; then
		export CCACHE_DIR=${DINNER_CCACHE_PATH}
	fi

	if [ ${DINNER_CCACHE_SIZE} ] && [ -z ${DINNER_CCACHE_SIZE##*[!0-9]*} ]; then
		_exec_command "${REPO_DIR}/prebuilts/misc/linux-x86/ccache/ccache -M ${DINNER_CCACHE_SIZE}" "_e_error \"There was an error while setting ccache size, take a look into the logs.\""
	fi

	if [ ${CLEANUP_OLDER_THAN} ] && [ -z "${CLEANUP_OLDER_THAN##*[!0-9]*}" ]; then
		_e_error "CLEANUP_OLDER_THAN has no valid number set, won't use it!"
		CLEANUP_OLDER_THAN=""
	fi

	if [ "${TARGET_DIR}" ]; then
		TARGET_DIR=$(echo "${TARGET_DIR}"|sed 's/\/$//g')
	fi
}

function _sync_repo () {
	if ! ${SKIP_SYNC} && [ -f "${DINNER_TEMP_DIR}/lastsync_$(echo ${REPO_DIR} | sed 's/\//_/g').txt" ] && [ $(($(date +%s)-$(cat "${DINNER_TEMP_DIR}/lastsync_$(echo ${REPO_DIR} | sed 's/\//_/g').txt"))) -lt ${SKIP_SYNC_TIME} ]; then
		_e_notice "Skipping repo sync, it was alread synced in the last ${SKIP_SYNC_TIME} seconds."
	else
		if ! ${SKIP_SYNC}; then
			_e_notice "Running repo sync..."
			_exec_command "${REPO_BIN} sync" "_e_warning \"Something went wrong  while doing repo sync\""
			CURRENT_SYNC_REPO_EXIT_CODE=$?
			if [ "${CURRENT_SYNC_REPO_EXIT_CODE}" == 0 ]; then
				echo $(date +%s) > "${DINNER_TEMP_DIR}/lastsync_${CURRENT_REPO_NAME}.txt"
			fi
		else
			_e_notice "Skipping repo sync..."
			CURRENT_SYNC_REPO_EXIT_CODE=0
		fi
	fi
}

function _repo_pick () {
	if [ "${CURRENT_REPOPICK}" ]; then
		if [ -x ${REPO_DIR}/build/tools/repopick.py ]; then
			export ANDROID_BUILD_TOP=${REPO_DIR}
			for CHANGE in ${CURRENT_REPOPICK}; do
				_exec_command "${REPO_DIR}/build/tools/repopick.py ${CHANGE}"
			done
		else
			_e_error "Could not find repopick.py, cannot make a repopick."
		fi
	fi
}

function _get_breakfast_variables () {
	_exec_command "breakfast ${CURRENT_DEVICE}" "_e_fatal \"Something went wrong while getting breakfast variables\""
	CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE=${?}
	if [ "${CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE}" == 0 ]; then
		for VARIABLE in $(breakfast ${CURRENT_DEVICE} | sed -e 's/^=.*//' -e 's/[ ^I]*$//' -e '/^$/d' | grep -E '^[A-Z_]+=(.*)'); do
			eval "${VARIABLE}"
		done
	fi
}

function _brunch_device () {
	_e_notice "Running brunch for config \"${CURRENT_CONFIG}\" (Device: ${CURRENT_DEVICE}) with version ${PLATFORM_VERSION}..."
	_exec_command "brunch ${CURRENT_DEVICE}" "NOTSET" "NOTSET"
	CURRENT_BRUNCH_DEVICE_EXIT_CODE=${?}
	CURRENT_OUTPUT_FILE=$(tail ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log | grep -i "Package complete:" | awk '{print $3}' | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" )
	CURRENT_BRUNCH_RUN_TIME=$(tail ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log | grep "real" | awk '{print $2}' | tr -d ' ')
	if [ "${CURRENT_BRUNCH_DEVICE_EXIT_CODE}" == 0 ]; then
		_e_success "Brunch of config ${CURRENT_CONFIG} finished after ${CURRENT_BRUNCH_RUN_TIME}"
		_check_build
		if ${CURRENT_BUILD_STATUS}; then
			CURRENT_STATUS="finished successfully"
			_post_build_command
			_move_build
			_clean_old_builds
		else
			CURRENT_POST_BUILD_COMMAND_EXIT_CODE=0
			CURRENT_MOVE_BUILD_EXIT_CODE=0
			CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=0
		fi
	else
		_e_error "Brunch of config ${CURRENT_CONFIG} failed after ${CURRENT_BRUNCH_RUN_TIME}, see logfile for more information"
	fi
}

function _move_build () {
	if [ "${CURRENT_TARGET_DIR}" ]; then
		if [ -d "${CURRENT_TARGET_DIR}/" ]; then
			_e_notice "Moving files to target directory..."
			_exec_command "mv ${CURRENT_OUTPUT_FILE}* ${CURRENT_TARGET_DIR}/" "_e_warning \"Something went wrong while moving the build\""
			CURRENT_MOVE_BUILD_EXIT_CODE=$?
		else
			_e_error "${CURRENT_TARGET_DIR}/ is not a Directory. Will not move the File."
		fi
	else
		CURRENT_MOVE_BUILD_EXIT_CODE=0
	fi
}

function _pre_build_command () {
	if [ ${CURRENT_PRE_BUILD_COMMAND} ]; then
		_e_notice "Running pre build command..."
		_exec_command "${CURRENT_PRE_BUILD_COMMAND}" "_e_warning \"Something went wrong while running your pre build command\""
		CURRENT_PRE_BUILD_COMMAND_EXIT_CODE=$?
	else
		CURRENT_PRE_BUILD_COMMAND_EXIT_CODE=0
	fi
}

function _post_build_command () {
	if [ ${CURRENT_POST_BUILD_COMMAND} ]; then
		_e_notice "Running post build command..."
		_exec_command "${CURRENT_POST_BUILD_COMMAND}" "_e_warning \"Something went wrong while running your post build command\""
		CURRENT_POST_BUILD_COMMAND_EXIT_CODE=$?
	else
		CURRENT_POST_BUILD_COMMAND_EXIT_CODE=0
	fi
}

function _clean_old_builds () {
	if [ "${CURRENT_CLEANUP_OLDER_THAN}" ]; then
		_e_notice "Running cleanup of old builds..."
		if [ "${CURRENT_TARGET_DIR}" ] && [ -d "${CURRENT_TARGET_DIR}/" ]; then
			CURRENT_CLEANED_FILES=$(find ${CURRENT_TARGET_DIR}/ -name "omni-${PLATFORM_VERSION}-*-${CURRENT_DEVICE}-HOMEMADE.zip*" -type f -mtime +${CURRENT_CLEANUP_OLDER_THAN} -delete)
		else
			CURRENT_CLEANED_FILES=$(find `dirname ${CURRENT_OUTPUT_FILE}` -name "omni-${PLATFORM_VERSION}-*-${CURRENT_DEVICE}-HOMEMADE.zip*" -type f -mtime +${CURRENT_CLEANUP_OLDER_THAN} -delete)
		fi
		CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=$?
		if [ "${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE}" != 0 ] && [ ! "${CURRENT_CLEANED_FILES}" ]; then
			CURRENT_CLEANED_FILES="Nothing to clean up for ${CURRENT_CONFIG}."
		elif [ "${CURRENT_CLEANED_FILES}" ]; then
			_e_notice "${CURRENT_CLEANED_FILES}"
		fi
		if [ "${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE}" != 0 ]; then
			_e_warning "Something went wrong while cleaning builds for ${CURRENT_CONFIG}." "${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE}"
		fi
	else
		CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=0
	fi
}

function _send_mail () {
	if [ "${CURRENT_MAIL}" ] || [ "${CURRENT_ADMIN_MAIL}" ]; then
		_e_notice "Sending status mail..."
		:> "${DINNER_TEMP_DIR}/mail_user_message_${CURRENT_CONFIG}.txt"
		:> "${DINNER_TEMP_DIR}/mail_admin_message_${CURRENT_CONFIG}.txt"

		if ${CURRENT_BUILD_STATUS}; then
			_generate_user_message "Build for ${CURRENT_DEVICE} was successfully finished after ${CURRENT_BRUNCH_RUN_TIME}\n"
			_generate_admin_message "Used config \"${CURRENT_CONFIG}\"\n"
			if [ "${CURRENT_DOWNLOAD_LINK}" ]; then
				_generate_user_message "You can download your Build at ${CURRENT_DOWNLOAD_LINK}\n\n"
			fi

			if [ -f ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt ]; then
				_generate_user_message "$($(which cat) ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt)"
			fi

			if [ "${CURRENT_CLEANED_FILES}" ]; then
				_generate_admin_message "Removed the following files:"
				_generate_admin_message "${CURRENT_CLEANED_FILES}"
			fi
		else
			_generate_user_message "Build has failed after ${CURRENT_BRUNCH_RUN_TIME}.\n\n"
			if [ -f ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log ]; then
				_generate_admin_message "Logfile attached"
				LOGFILE="-A \"\"${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log\"\""
			else
				_generate_admin_message "ERROR: Logfile not found"
			fi
		fi

		_generate_user_message "\e[21m"

		if [ "${CURRENT_MAIL}" ]; then
			_exec_command "$(which cat) \"${DINNER_TEMP_DIR}/mail_user_message_${CURRENT_CONFIG}.txt\" | ${ANSI2HTML_BIN} | ${MAIL_BIN} -a \"Content-type: text/html\" -s \"[Dinner] Build for ${CURRENT_DEVICE} ${CURRENT_STATUS} (${CURRENT_BRUNCH_RUN_TIME})\" \"${CURRENT_MAIL}\"" "_e_warning \"Something went wrong while sending User E-Mail\""
			CURRENT_SEND_MAIL_EXIT_CODE=$?
		fi

		if [ "${CURRENT_ADMIN_MAIL}" ]; then
			_exec_command "$(which cat) \"${DINNER_TEMP_DIR}/mail_user_message_${CURRENT_CONFIG}.txt\" \"${DINNER_TEMP_DIR}/mail_admin_message_${CURRENT_CONFIG}.txt\" | ${ANSI2HTML_BIN} | ${MAIL_BIN} ${LOGFILE} -a \"Content-type: text/html\" -s \"[Dinner] Build for ${CURRENT_DEVICE} ${CURRENT_STATUS} (${CURRENT_BRUNCH_RUN_TIME})\" \"${CURRENT_ADMIN_MAIL}\"" "_e_warning \"Something went wrong while sending Admin E-Mail\""
			CURRENT_SEND_MAIL_EXIT_CODE=$(($CURRENT_SEND_MAIL_EXIT_CODE + $?))
		fi
	else
		CURRENT_SEND_MAIL_EXIT_CODE=0
	fi
}

function _check_build () {
	if [ -f "${CURRENT_OUTPUT_FILE}" ]; then
		CURRENT_OUT_FILE_SECONDS_SINCE_CREATION=$(/bin/date -d "now - $( /usr/bin/stat -c "%Y" ${CURRENT_OUTPUT_FILE} ) seconds" +%s)
		if [ "${CURRENT_OUT_FILE_SECONDS_SINCE_CREATION}" -lt "120" ] ; then
			CURRENT_BUILD_STATUS=true
		else
			_e_error "Outputfile too old!"
		fi
	else
		_e_error "Outputfile does not exist!"
	fi
}

function _dinner_make {
	if [ ${CURRENT_DINNER_MAKE} ]; then
		CURRENT_BUILD_SKIPPED=true
		_e_notice "Running \"make ${DINNER_MAKE}\"..."
		_exec_command "make ${DINNER_MAKE}"
		if ${CURRENT_CLEAN_ONLY}; then
			_check_current_config
			continue
		fi
	fi
}

function _check_current_config () {
	CURRENT_CONFIG_EXIT_CODE=$(( \
		${SYNC_REPO_EXIT_CODE} \
		+${CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE} \
		+${CURRENT_BRUNCH_DEVICE_EXIT_CODE} \
		+${CURRENT_MOVE_BUILD_EXIT_CODE} \
		+${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE} \
		+${CURRENT_SEND_MAIL_EXIT_CODE} \
	))
	if ${CURRENT_BUILD_SKIPPED}; then
		_e_notice "All jobs for config \"${CURRENT_CONFIG}\" finished successfully."
		SUCCESS_CONFIGS="${SUCCESS_CONFIGS}${CURRENT_CONFIG}; "
	elif ${CURRENT_BUILD_STATUS} && [ "${CURRENT_CONFIG_EXIT_CODE}" -eq 0 ]; then
		_e_notice "All jobs for config \"${CURRENT_CONFIG}\" finished successfully."
		SUCCESS_CONFIGS="${SUCCESS_CONFIGS}${CURRENT_CONFIG}; "
		_set_lastbuild
	elif ${CURRENT_BUILD_STATUS} && [ "${CURRENT_CONFIG_EXIT_CODE}" -gt 0 ]; then
		_e_warning "Buildcheck for config \"${CURRENT_CONFIG}\" was successful but something else went wrong" "${CURRENT_CONFIG_EXIT_CODE}"
		WARNING_CONFIGS="${WARNING_CONFIGS}${CURRENT_CONFIG}; "
	elif ! ${CURRENT_BUILD_STATUS} && [ "${CURRENT_CONFIG_EXIT_CODE}" -eq 0 ]; then
		_e_error "Buildcheck for config \"${CURRENT_CONFIG}\" has failed but overall exit code is fine" "${CURRENT_CONFIG_EXIT_CODE}"
		FAILED_CONFIGS="${FAILED_CONFIGS}${CURRENT_CONFIG}; "
	elif ! ${CURRENT_BUILD_STATUS}; then
		_e_error "Build for config \"${CURRENT_CONFIG}\" has failed" "${CURRENT_CONFIG_EXIT_CODE}"
		FAILED_CONFIGS="${FAILED_CONFIGS}${CURRENT_CONFIG}; "
	else
		_e_error "Could not determine status for config \"${CURRENT_CONFIG}\"" "${CURRENT_CONFIG_EXIT_CODE}"
	fi
	echo -e ""
	OVERALL_EXIT_CODE=$((${OVERALL_EXIT_CODE}+${CURRENT_CONFIG_EXIT_CODE}))
}

function _set_lastbuild () {
	echo $(date +%m/%d/%Y) > ${DINNER_TEMP_DIR}/lastbuild_${CURRENT_CONFIG}.txt
}

function _get_changelog () {
	if [ -f "${DINNER_TEMP_DIR}/lastbuild_${CURRENT_CONFIG}.txt" ]; then
		_e_notice "Gathering Changes since last successfull build..."
		LASTBUILD=$($(which cat) ${DINNER_TEMP_DIR}/lastbuild_${CURRENT_CONFIG}.txt)

		echo -e "\nChanges since last build ${LASTBUILD}"  > ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt
		echo -e "=====================================================\n"  >> ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt
		find ${REPO_DIR} -name .git | sed 's/\/.git//g' | sed 'N;$!P;$!D;$d' | while read line
		do
			cd $line
			log=$(git log --pretty="%an - %s" --since=${LASTBUILD} --date-order)
			project=$(git remote -v | head -n1 | awk '{print $2}' | sed 's/.*\///' | sed 's/\.git//')
			if [ ! -z "$log" ]; then
				origin=`grep "$project" ${REPO_DIR}/.repo/manifest.xml | awk {'print $4'} | cut -f2 -d '"'`

				if [ "$origin" = "bam" ]; then
						proj_credit=JELLYBAM
				elif [ "$origin" = "aosp" ]; then
						proj_credit=AOSP
				elif [ "$origin" = "cm" ]; then
						proj_credit=CyanogenMod
				else
						proj_credit="OmniROM"
				fi

				echo "$proj_credit Project name: $project" >> ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt

				echo "$log" | while read line
				do
					echo "  .$line" >> ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt
				done

				echo "" >> ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt
			fi
		done
		if ${CURRENT_CHANGELOG_ONLY}; then
			CURRENT_BUILD_SKIPPED=true
			[[ -f ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt ]] && cat ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt || _e_fatal "No Changelog found"
			_check_current_config
			continue
		fi
	else
		_e_notice "Skipping gathering changes, no successfull build for config \"${CURRENT_CONFIG}\" found..."
		if ${CURRENT_CHANGELOG_ONLY}; then
			CURRENT_BUILD_SKIPPED=true
			[[ -f ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt ]] && _e_notice "Showing last found changelog:" && cat ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt || _e_warning "No Changelog found"
			_check_current_config
			continue
		fi
	fi

}

function _run_config () {
	case ${1} in
		"changelog")
			CURRENT_CHANGELOG_ONLY=true
			CURRENT_CONFIG=${2}
			;;
		"clean")
			CURRENT_CLEAN_ONLY=true
			CURRENT_DINNER_MAKE=${2}
			CURRENT_CONFIG=${3}
			;;
		"cook")
			CURRENT_CONFIG=${2}
			;;
		*)
			_e_fatal "Unknown command '$1'" $EX_USAGE
	esac

	_check_prerequisites

	_dinner_make

	_sync_repo

	_repo_pick

	_get_changelog

	_get_breakfast_variables

	_pre_build_command

	_brunch_device

	_send_mail

	_check_current_config
}

function _list_configs {
	printf "${bldwht}%s${txtdef}\n" "Available Configs:"
	while IFS= read -d $'\n' -r config ; do
		printf "\t\t%s\n" "$config"
done < <(_print_configs)
	exit $EX_SUCCESS
}

function _print_configs {
	while IFS= read -d $'\0' -r configpath ; do
		local config=$(basename "${configpath}")
		printf "$config\n"
	done < <(find "${CONFIG_DIR}" -mindepth 1 -maxdepth 1 -type f ! -name *example.dist -print0 | sort -z)
	return $EX_SUCCESS
}
