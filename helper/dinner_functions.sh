#!/bin/bash
function _exec_command () {
	if ${SHOW_VERBOSE}; then
		# log STDOUT and STDERR, send both to STDOUT
		eval "${1} &> >(tee -a ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log)"
	else
		# log STDOUT and STDERR but send only STDERR to STDOUT
		eval "${1} &>> ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log"
	fi
}

function _generate_user_message () {
	echo -e "${1}" >> "${DINNER_TEMP_DIR}/mail_user_message_${CURRENT_CONFIG}.txt"
}

function _generate_admin_message () {
	echo -e "${1}" >> "${DINNER_TEMP_DIR}/mail_admin_message_${CURRENT_CONFIG}.txt"
}

function _check_prerequisites () {
	_check_variables

	_source_envsetup

	if [ -f "${DINNER_TEMP_DIR}/lastsync_$(echo ${REPO_DIR} | sed 's/\//_/g').txt" ]; then
		if ! ${SKIP_SYNC} && [ $(($(date +%s)-$(cat "${DINNER_TEMP_DIR}/lastsync_$(echo ${REPO_DIR} | sed 's/\//_/g').txt"))) -lt ${SKIP_SYNC_TIME} ]; then
			_e_notice "Skipping repo sync, it was alread synced in the last ${SKIP_SYNC_TIME} seconds."
			SKIP_SYNC=true
		fi
	fi
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

	for DINNER_OPTION in ${DINNER_OPTIONS}; do
		case ${DINNER_OPTION} in
			"cron")
				DINNER_CRON=true
			;;
			"make_installclean")
				if [ ${DINNER_MAKE} ]; then
					_e_fatal "Use only one make command!"
				else
					DINNER_MAKE="make installclean"
				fi
			;;
			"make_clean")
				if [ ${DINNER_MAKE} ]; then
					_e_fatal "Use only one make command!"
				else
					DINNER_MAKE="make clean"
				fi
			;;
		esac
	done

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
		_exec_command "${REPO_DIR}/prebuilts/misc/linux-x86/ccache/ccache -M ${DINNER_CCACHE_SIZE}"
		if [ ${?} != 0 ]; then
			_e_error "There was an error while setting ccache size, take a look into the logs."
		fi
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
	_e_notice "Running repo sync..."
	_exec_command "${REPO_BIN} sync"
	CURRENT_SYNC_REPO_EXIT_CODE=$?
	if [ "${CURRENT_SYNC_REPO_EXIT_CODE}" != 0 ]; then
		_e_warning "Something went wrong  while doing repo sync" "${CURRENT_SYNC_REPO_EXIT_CODE}"
	else
		echo $(date +%s) > "${DINNER_TEMP_DIR}/lastsync_${CURRENT_REPO_NAME}.txt"
	fi
}

function _get_breakfast_variables () {
	_exec_command "breakfast ${CURRENT_DEVICE}"
	CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE=${?}
	if [ "${CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE}" == 0 ]; then
		for VARIABLE in $(breakfast ${CURRENT_DEVICE} | sed -e 's/^=.*//' -e 's/[ ^I]*$//' -e '/^$/d' | grep -E '^[A-Z_]+=(.*)'); do
			eval "${VARIABLE}"
		done
	else
		_e_fatal "Something went wrong while getting breakfast variables"
	fi
}

function _brunch_device () {
	_e_notice "Running brunch for config \"${CURRENT_CONFIG}\" (Device: ${CURRENT_DEVICE}) with version ${PLATFORM_VERSION}... \c"
	_exec_command "brunch ${CURRENT_DEVICE}"
	CURRENT_BRUNCH_DEVICE_EXIT_CODE=${?}
	CURRENT_OUTPUT_FILE=$(tail ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log | grep -i "Package complete:" | awk '{print $3}' | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" )
	CURRENT_BRUNCH_RUN_TIME=$(tail ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log | grep "real" | awk '{print $2}' | tr -d ' ')
	if [ "${CURRENT_BRUNCH_DEVICE_EXIT_CODE}" != 0 ]; then
		echo -e "failed after ${CURRENT_BRUNCH_RUN_TIME}"
		_e_error "Config ${CURRENT_CONFIG} failed, see logfile for more information" "${CURRENT_BRUNCH_DEVICE_EXIT_CODE}"
	else
		echo -e "finished after ${CURRENT_BRUNCH_RUN_TIME}"
	fi
}

function _move_build () {
	if [ -d "${CURRENT_TARGET_DIR}/" ]; then
		_e_notice "Moving files to target directory..."
		_exec_command "mv ${CURRENT_OUTPUT_FILE}* ${CURRENT_TARGET_DIR}/"
		CURRENT_MOVE_BUILD_EXIT_CODE=$?
		if [ "${CURRENT_MOVE_BUILD_EXIT_CODE}" != 0 ]; then
			_e_warning "Something went wrong while moving the build" "${CURRENT_MOVE_BUILD_EXIT_CODE}"
		fi
	else
		_e_error "${CURRENT_TARGET_DIR}/ is not a Directory. Will not move the File."
	fi
}

function _pre_build_command () {
	_e_notice "Running pre build command..."
	_exec_command "${CURRENT_PRE_BUILD_COMMAND}"
	CURRENT_PRE_BUILD_COMMAND_EXIT_CODE=$?
	if [ "${CURRENT_PRE_BUILD_COMMAND_EXIT_CODE}" != 0 ]; then
		_e_warning "Something went wrong while running your pre build command" "${CURRENT_PRE_BUILD_COMMAND_EXIT_CODE}"
	fi
}

function _post_build_command () {
	_e_notice "Running post build command..."
	_exec_command "${CURRENT_POST_BUILD_COMMAND}"
	CURRENT_POST_BUILD_COMMAND_EXIT_CODE=$?
	if [ "${CURRENT_POST_BUILD_COMMAND_EXIT_CODE}" != 0 ]; then
		_e_warning "Something went wrong while running your post build command" "${CURRENT_POST_BUILD_COMMAND_EXIT_CODE}"
	fi
}

function _clean_old_builds () {
	_e_notice "Running cleanup of old builds..."
	if [ "${CURRENT_TARGET_DIR}" ] && [ -d "${CURRENT_TARGET_DIR}/" ]; then
		CURRENT_CLEANED_FILES=$(find ${CURRENT_TARGET_DIR}/ -name "omni-${PLATFORM_VERSION}-*-${CURRENT_DEVICE}-HOMEMADE.zip*" -type f -mtime +${CLEANUP_OLDER_THAN} -delete)
	else
		CURRENT_CLEANED_FILES=$(find `dirname ${CURRENT_OUTPUT_FILE}` -name "omni-${PLATFORM_VERSION}-*-${CURRENT_DEVICE}-HOMEMADE.zip*" -type f -mtime +${CLEANUP_OLDER_THAN} -delete)
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
}

function _send_mail () {
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
		_generate_admin_message "Logfile:"
		if [ -f ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log ]; then
			_generate_admin_message "$($(which cat) ${DINNER_LOG_DIR}/dinner_${CURRENT_CONFIG}_${CURRENT_LOG_TIME}.log)"
		else
			_generate_admin_message "ERROR: Logfile not found"
		fi
	fi

	_generate_user_message "\e[21m"

	if [ "${CURRENT_MAIL}" ]; then
		_exec_command "$(which cat) \"${DINNER_TEMP_DIR}/mail_user_message_${CURRENT_CONFIG}.txt\" | ${ANSI2HTML_BIN} | ${MAIL_BIN} -a \"Content-type: text/html\" -s \"[Dinner] Build for ${CURRENT_DEVICE} ${CURRENT_STATUS} (${CURRENT_BRUNCH_RUN_TIME})\" \"${CURRENT_MAIL}\""
	fi

	if [ "${CURRENT_ADMIN_MAIL}" ]; then
		_exec_command "$(which cat) \"${DINNER_TEMP_DIR}/mail_user_message_${CURRENT_CONFIG}.txt\" \"${DINNER_TEMP_DIR}/mail_admin_message_${CURRENT_CONFIG}.txt\" | ${ANSI2HTML_BIN} | ${MAIL_BIN} -a \"Content-type: text/html\" -s \"[Dinner] Build for ${CURRENT_DEVICE} ${CURRENT_STATUS} (${CURRENT_BRUNCH_RUN_TIME})\" \"${CURRENT_ADMIN_MAIL}\""
	fi
	CURRENT_SEND_MAIL_EXIT_CODE=$?
	if [ "${CURRENT_SEND_MAIL_EXIT_CODE}" != 0 ]; then
		_e_warning "Something went wrong while sending E-Mail" "${CURRENT_SEND_MAIL_EXIT_CODE}"
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

function _set_lastbuild () {
	echo $(date +%m/%d/%Y) > ${DINNER_TEMP_DIR}/lastbuild_${CURRENT_CONFIG}.txt
}

function _get_changelog () {
	if [ -f "${DINNER_TEMP_DIR}/lastbuild_${CURRENT_CONFIG}.txt" ]; then
		_e_notice "Gathering Changes since last build..."
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
	else
	    _e_warning "There was never a successfull build so we have no changes"
	fi
}

function _run_config () {
	CURRENT_CONFIG=${1}
	if [ -f "${DINNER_DIR}/config.d/${CURRENT_CONFIG}" ]; then
		. ${DINNER_DIR}/config.d/${CURRENT_CONFIG}
	else
		_e_fatal "Config \"${CURRENT_CONFIG}\" not found!"
	fi

	_check_prerequisites

	_e_notice "Starting work on config \"${CURRENT_CONFIG}\"..."

	cd "${REPO_DIR}"

	if [ -x ${REPO_DIR}/vendor/cm/get-prebuilts ]; then
		_exec_command "${REPO_DIR}/vendor/cm/get-prebuilts"
	fi

	if [ ${DINNER_MAKE} ]; then
		_exec_command "${DINNER_MAKE}"
	fi

	#Set initial exitcodes
	OVERALL_EXIT_CODE=0
	CURRENT_SYNC_REPO_EXIT_CODE=1
	CURRENT_BUILD_STATUS=false
	CURRENT_CONFIG_EXIT_CODE=1
	CURRENT_BRUNCH_DEVICE_EXIT_CODE=1
	CURRENT_MOVE_BUILD_EXIT_CODE=1
	CURRENT_PRE_BUILD_COMMAND_EXIT_CODE=1
	CURRENT_POST_BUILD_COMMAND_EXIT_CODE=1
	CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=1
	CURRENT_SEND_MAIL_EXIT_CODE=1
	CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE=1

	#Set current config Variables
	eval CURRENT_REPO_NAME=$(echo ${REPO_DIR} | sed 's/\//_/g')
	eval CURRENT_REPOPICK="\"${REPOPICK}\""
	eval CURRENT_DEVICE="${BUILD_FOR_DEVICE}"
	eval CURRENT_PRE_BUILD_COMMAND="${PRE_BUILD_COMMAND}"
	eval CURRENT_POST_BUILD_COMMAND="${POST_BUILD_COMMAND}"
	eval CURRENT_TARGET_DIR="${TARGET_DIR}"
	eval CURRENT_MAIL="${MAIL}"
	eval CURRENT_ADMIN_MAIL="${ADMIN_MAIL}"
	eval CURRENT_DOWNLOAD_LINK="${DOWNLOAD_LINK}"
	eval CURRENT_LOG_TIME="$(date +%Y%m%d-%H%M)"
	eval CURRENT_STATUS="failed"

	if ! ${SKIP_SYNC}; then
		_sync_repo
	else
		CURRENT_SYNC_REPO_EXIT_CODE=0
	fi

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

	case ${2} in
		"changelog")
			_get_changelog
			[[ -f ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt ]] && cat ${DINNER_TEMP_DIR}/changes_${CURRENT_CONFIG}.txt || _e_fatal "No Changelog found"
			exit 0
			;;
		"clean");;
		esac

	_get_changelog

	_get_breakfast_variables

	if [ ${CURRENT_PRE_BUILD_COMMAND} ]; then
		_pre_build_command
	else
		CURRENT_PRE_BUILD_COMMAND_EXIT_CODE=0
	fi

	_brunch_device

	if [ "${CURRENT_BRUNCH_DEVICE_EXIT_CODE}" == 0 ]; then
		_check_build
		if ${CURRENT_BUILD_STATUS}; then
			CURRENT_STATUS="finished successfully"
			if [ ${CURRENT_POST_BUILD_COMMAND} ]; then
				_post_build_command
			else
				CURRENT_POST_BUILD_COMMAND_EXIT_CODE=0
			fi
			if [ "${CURRENT_TARGET_DIR}" ]; then
				_move_build
			else
				CURRENT_MOVE_BUILD_EXIT_CODE=0
			fi
			if [ "${CLEANUP_OLDER_THAN}" ]; then
				_clean_old_builds
			else
				CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=0
			fi
		else
			CURRENT_POST_BUILD_COMMAND_EXIT_CODE=0
			CURRENT_MOVE_BUILD_EXIT_CODE=0
			CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE=0
		fi
	fi


	if [ "${CURRENT_MAIL}" ] || [ "${CURRENT_ADMIN_MAIL}" ]; then
		_send_mail
	else
		CURRENT_SEND_MAIL_EXIT_CODE=0
	fi

	CURRENT_CONFIG_EXIT_CODE=$(( \
		${SYNC_REPO_EXIT_CODE} \
		+${CURRENT_GET_BREAKFAST_VARIABLES_EXIT_CODE} \
		+${CURRENT_BRUNCH_DEVICE_EXIT_CODE} \
		+${CURRENT_MOVE_BUILD_EXIT_CODE} \
		+${CURRENT_CLEAN_OLD_BUILDS_EXIT_CODE} \
		+${CURRENT_SEND_MAIL_EXIT_CODE} \
	))
	if ${CURRENT_BUILD_STATUS} && [ "${CURRENT_CONFIG_EXIT_CODE}" -eq 0 ]; then
		_e_notice "All jobs for config \"${CURRENT_CONFIG}\" finished successfully."
		SUCCESS_CONFIGS="${SUCCESS_CONFIGS}${CURRENT_CONFIG}; "
		_set_lastbuild
	elif ${CURRENT_BUILD_STATUS} && [ "${CURRENT_CONFIG_EXIT_CODE}" -gt 0 ]; then
		_e_warning "Buildcheck for config \"${CURRENT_CONFIG}\" was successful but something else went wrong" "${CURRENT_CONFIG_EXIT_CODE}"
		WARNING_CONFIGS="${WARNING_CONFIGS}${CURRENT_CONFIG}; "
	elif [ "${CURRENT_BUILD_STATUS}" == "false" ] && [ "${CURRENT_CONFIG_EXIT_CODE}" -eq 0 ]; then
		_e_error "Buildcheck for config \"${CURRENT_CONFIG}\" has failed but overall exit code is fine" "${CURRENT_CONFIG_EXIT_CODE}"
		FAILED_CONFIGS="${FAILED_CONFIGS}${CURRENT_CONFIG}; "
	else
		_e_error "Could not determine status for config \"${CURRENT_CONFIG}\"" "${CURRENT_CONFIG_EXIT_CODE}"
	fi
	echo -e ""
	OVERALL_EXIT_CODE=$((${OVERALL_EXIT_CODE}+${CURRENT_CONFIG_EXIT_CODE}))
}

function list {
	printf "${bldwht}%s${txtdef}\n" "Available Configs:"
	while IFS= read -d $'\n' -r config ; do
		printf "\t\t%s\n" "$config"
	done < <(list_configs)
	exit $EX_SUCCESS
}

function list_configs {
	while IFS= read -d $'\0' -r configpath ; do
		local config=$(basename "${configpath}")
		printf "$config\n"
	done < <(find "${CONFIG_DIR}" -mindepth 1 -maxdepth 1 -type f ! -name *example.dist -print0 | sort -z)
	return $EX_SUCCESS
}
