#!/bin/bash

# Validate a directory setting used by destructive commands.
# Usage: validate_dir_setting VAR_NAME [must_exist]
# Value must be non-empty, end with a slash and not be "/".
function validate_dir_setting
{
	local NAME=$1
	local VALUE="${!1}"

	if [ -z "${VALUE}" ]; then
		echo "${P_NAME}: error: ${NAME} is not set."
		return 1
	fi
	if [ "${VALUE}" == "/" ]; then
		echo "${P_NAME}: error: ${NAME} must not be \"/\"."
		return 1
	fi
	if [ "${VALUE: -1}" != "/" ]; then
		echo "${P_NAME}: error: ${NAME} must end with a slash: ${VALUE}"
		return 1
	fi
	if [ "$2" == "must_exist" ] && [ ! -d "${VALUE}" ]; then
		echo "${P_NAME}: error: ${NAME} directory does not exist: ${VALUE}"
		return 1
	fi
	return 0
}

# Validate a non-empty (non-path) setting.
function validate_setting
{
	if [ -z "${!1}" ]; then
		echo "${P_NAME}: error: $1 is not set."
		return 1
	fi
	return 0
}

# Validate a positive integer setting.
function validate_number_setting
{
	if ! [[ "${!1}" =~ ^[0-9]+$ ]]; then
		echo "${P_NAME}: error: $1 must be a number: ${!1}"
		return 1
	fi
	return 0
}

# Filesystem backup - archive and move daily directories.
# Each directory is deleted only after its archive was created and moved.
function backup_fs_day
{
  echo "${P_NAME}: command: ${FUNCNAME[0]}"

  validate_dir_setting BK_SOURCE must_exist || return 1
  validate_dir_setting BK_TARGET || return 1

  # create directory tree if not exist
  mkdir -p "${BK_TARGET}" || return 1

  local TODAY
  TODAY=$(date +"%Y%m%d")
  local RESULT=0

  # archive all dirs, except today
  while IFS= read -r -d '' SOURCE_DIR; do
    local DIR_NAME
    DIR_NAME=$(basename "${SOURCE_DIR}")
    local ZIP_FILE="${BK_SOURCE}${DIR_NAME}.zip"

    echo "Archiving ${DIR_NAME}"
    if ! 7z a -mx=9 "${ZIP_FILE}" "${SOURCE_DIR}"; then
      echo "${P_NAME}: error: archiving failed, keeping ${SOURCE_DIR}"
      RESULT=1
      continue
    fi

    if ! mv "${ZIP_FILE}" "${BK_TARGET}"; then
      echo "${P_NAME}: error: moving failed, keeping ${SOURCE_DIR}"
      RESULT=1
      continue
    fi

    # delete only date directories (YYYYMMDD)
    if [[ "${DIR_NAME}" =~ ^[0-9]{8}$ ]]; then
      rm -rf "${SOURCE_DIR}"
      echo "Deleted ${SOURCE_DIR}"
    fi
  done < <(find "${BK_SOURCE}" -mindepth 1 -maxdepth 1 -type d ! -name "${TODAY}" -print0)

  echo "Done."
  return ${RESULT}
}

# Filesystem backup
function backup_fs
{
	echo "${P_NAME}: command: ${FUNCNAME[0]}"

	NOW=`date "+%y%m%d-%H%M%S"`

	DIR="${BK_TARGET}${BK_NAME}/${BK_TYPE}/"

	# create directory tree if not exist
	mkdir -p "${DIR}"

	echo "Creating backup for directory ${BK_SOURCE}"

	# create backup file
	tar -pczf "${DIR}${BK_NAME}_${NOW}.tar.gz" "${BK_SOURCE}" > /dev/null 2>&1
}

# Filesystem backup
# Special situation for WSFW log systems
function backup_fs_log
{
	echo "${P_NAME}: command: ${FUNCNAME[0]}"
	echo "${P_NAME}: backup name: ${BK_NAME}"

	validate_dir_setting BK_SOURCE must_exist || return 1
	validate_dir_setting BK_TARGET || return 1
	validate_setting BK_NAME || return 1

	NOW=`date "+%y%m%d-%H%M%S"`

	DIR="${BK_TARGET}${BK_NAME}/${BK_TYPE}/"

	# create directory tree if not exist
	mkdir -p "${DIR}" || return 1

	echo "Creating backup for directory ${BK_SOURCE}"

	# Create backup file (zip)
	# Source files are cleared only if the archive was created successfully
	if ! 7z a -mx=9 "${DIR}${BK_NAME}_${NOW}.zip" "${BK_SOURCE}"; then
		echo "${P_NAME}: error: archiving failed, source files not cleared."
		return 1
	fi

	# Delete .context files
	echo "Delete .context files"
	find "${BK_SOURCE}" -type f  \( -iname '*.context' \) -mmin +1 -delete

	# Clear (truncate) .log files
	echo "Clear .log files"
	# Make sure to not put the wildcard inside the quotes
	truncate -s 0 "${BK_SOURCE}"*.log

	echo "${P_NAME}: backup complete: ${BK_NAME}"
}

# Database backup
function backup_db
{
        echo "${P_NAME}: command: ${FUNCNAME[0]}"

        echo "show databases;" | ${BK_EXECUTABLE_MYSQL} -h "${BK_DB_HOST}" -P "${BK_DB_PORT}" -u "${BK_DB_USER}" "-p${BK_DB_PASS}" -N | while read -r DB_NAME;
        do
                #echo "Process ${DB_NAME}"
                echo 'mysql information_schema performance_schema' | grep -qw -- "${DB_NAME}"
                if [ $? -eq 0 ] ; then
                        echo "Skiping database ${DB_NAME}"
                else
                        match=0
                        for DB_NAME_IGNORE in "${BK_DB_IGNORE[@]}"; do
                                if [[ $DB_NAME_IGNORE == "${DB_NAME}" ]]; then
                                        match=1
                                        break
                                fi
                        done

                        if [[ $match == 1 ]]; then
                                echo "Ignoring ${DB_NAME}"
                        else

                                DIR="${BK_TARGET}${BK_NAME}/${BK_TYPE}/${DB_NAME}/"

                                # create directory tree if not exist
                                mkdir -p "${DIR}"

                                echo "Creating backup for database ${DB_NAME}"

                                ${BK_EXECUTABLE_MYSQLDUMP} -h "${BK_DB_HOST}" -P "${BK_DB_PORT}" -u "${BK_DB_USER}" "-p${BK_DB_PASS}" --lock-all-tables --complete-insert --add-drop-table "${DB_NAME}" | gzip -c > "${DIR}${DB_NAME}_`date "+%y%m%d-%H%M%S"`.sql.gz"
                        fi
                fi

        done
}

function backup_cleanup_days
{
	echo "${P_NAME}: command: ${FUNCNAME[0]}"

	validate_dir_setting BK_TARGET || return 1
	validate_setting BK_NAME || return 1
	validate_number_setting BK_KEEP_DAYS || return 1

	echo "${P_NAME}: Cleaning up files older than ${BK_KEEP_DAYS} days"

	backup_cleanup_days_func "${BK_TARGET}${BK_NAME}/${BK_TYPE}" "${BK_KEEP_DAYS}"

	# database backups will have subdirectories
	find "${BK_TARGET}${BK_NAME}/${BK_TYPE}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | while read -r DIR
	do
		backup_cleanup_days_func "${BK_TARGET}${BK_NAME}/${BK_TYPE}/${DIR}" "${BK_KEEP_DAYS}"
	done
}

function backup_cleanup_days_func
{
	DIR_PATH=$1
	KEEP_DAYS=$2

	find "${DIR_PATH}" -maxdepth 1 -mtime +"${KEEP_DAYS}" -type f -printf "%f\n"| while IFS= read -r FILE;
	do
		echo "Deleting file ${FILE}"

		rm -f "${DIR_PATH}/${FILE}";
	done
}

function backup_cleanup_numfiles
{
	echo "${P_NAME}: command: ${FUNCNAME[0]}"

	validate_dir_setting BK_TARGET || return 1
	validate_setting BK_NAME || return 1
	validate_number_setting BK_KEEP_NUMFILES || return 1

	echo "${P_NAME}: Cleaning up files exceeding ${BK_KEEP_NUMFILES} in number"

	backup_cleanup_numfiles_func "${BK_TARGET}${BK_NAME}/${BK_TYPE}" "${BK_KEEP_NUMFILES}"

	# database backups will have subdirectories
	find "${BK_TARGET}${BK_NAME}/${BK_TYPE}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | while read -r DIR
	do
		backup_cleanup_numfiles_func "${BK_TARGET}${BK_NAME}/${BK_TYPE}/${DIR}" "${BK_KEEP_NUMFILES}"
	done

}

function backup_cleanup_numfiles_func
{
	DIR_PATH=$1
	KEEP_NUMFILES=$2

	# sort by modification time, newest first, so the newest files are kept
	find "${DIR_PATH}" -maxdepth 1 -type f -printf "%T@ %f\n" | sort -rn | cut -d' ' -f2- | awk -v keep="${KEEP_NUMFILES}" 'NR>keep' | while IFS= read -r FILE;
	do
		echo "Deleting file ${FILE}"

		rm -f "${DIR_PATH}/${FILE}";
	done
}
