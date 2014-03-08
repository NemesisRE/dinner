#For compatibility set Language to en_US.UTF8 and timezone to UTC
export LANGUAGE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"
export TZ="/usr/share/zoneinfo/UTC"

CONFIG_DIR="${DINNER_DIR}/config.d"
DINNER_LOG_DIR="${DINNER_DIR}/logs"
DINNER_TEMP_DIR="${DINNER_DIR}/tmp"

DINNER_USE_CCACHE="1"
DINNER_CRON=false
SHOW_VERBOSE=false
SKIP_SYNC=false
SKIP_SYNC_TIME="1800"
GET_CHANGELOG_ONLY=false
