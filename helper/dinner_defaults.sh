#For compatibility set Language to en_US.UTF8 and timezone to UTC
BACKUP_ENV[0]="LANGUAGE=\"${LANGUAGE}\"" && export LANGUAGE="en_US.UTF-8"
BACKUP_ENV[1]="LC_ALL=\"${LC_ALL}\"" && export LC_ALL="en_US.UTF-8"
BACKUP_ENV[2]="LANG=\"${LANG}\"" && export LANG="en_US.UTF-8"
BACKUP_ENV[3]="TZ=\"${TZ}\"" && export TZ="/usr/share/zoneinfo/UTC"

CONFIG_DIR="${DINNER_DIR}/config.d"
DINNER_LOG_DIR="${DINNER_DIR}/logs"
DINNER_MEM_DIR="${DINNER_DIR}/memory"
DINNER_TEMP_DIR="${DINNER_DIR}/tmp"

DINNER_USE_CCACHE="1"
DINNER_CRON=false
SHOW_VERBOSE=false
SKIP_SYNC=false
SKIP_SYNC_TIME="1800"
GET_CHANGELOG_ONLY=false
