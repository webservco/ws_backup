#!/bin/bash

# Filesystem backup
function backup_fs
{
	echo "${P_NAME}: command: ${FUNCNAME[0]}"

	NOW=`date "+%y%m%d-%H%M%S"`

	DIR="${BK_TARGET}${BK_NAME}/${BK_TYPE}/"

	# create directory tree if not exist
	mkdir -p ${DIR}

	echo "Creating backup for directory ${BK_SOURCE}"

	# create backup file
	tar -pczf "${DIR}${BK_NAME}_${NOW}.tar.gz" ${BK_SOURCE} > /dev/null 2>&1
}

# Filesystem backup
# Special situation for WSFW log systems
function backup_fs_log
{
	echo "${P_NAME}: command: ${FUNCNAME[0]}"
	echo "${P_NAME}: backup name: ${BK_NAME}"

	NOW=`date "+%y%m%d-%H%M%S"`

	DIR="${BK_TARGET}${BK_NAME}/${BK_TYPE}/"

	# create directory tree if not exist
	mkdir -p ${DIR}

	echo "Creating backup for directory ${BK_SOURCE}"

	# Create backup file (zip)
	# 7z a -mx=9 "${DIR}${BK_NAME}_${NOW}.zip" "${BK_SOURCE}" > /dev/null 2>&1
	7z a -mx=9 "${DIR}${BK_NAME}_${NOW}.zip" "${BK_SOURCE}"

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

        echo "show databases;" | ${BK_EXECUTABLE_MYSQL} -h ${BK_DB_HOST} -P ${BK_DB_PORT} -u ${BK_DB_USER} -p${BK_DB_PASS} -N | while read DB_NAME;
        do
                #echo "Process ${DB_NAME}"
                echo 'mysql information_schema performance_schema' | grep -qw ${DB_NAME}
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
                                mkdir -p ${DIR}

                                echo "Creating backup for database ${DB_NAME}"

                                ${BK_EXECUTABLE_MYSQLDUMP} -h ${BK_DB_HOST} -P ${BK_DB_PORT} -u ${BK_DB_USER} -p${BK_DB_PASS} --lock-all-tables --complete-insert --add-drop-table ${DB_NAME} | gzip -c > "${DIR}${DB_NAME}_`date "+%y%m%d-%H%M%S"`.sql.gz"
                        fi
                fi

        done
}

function backup_cleanup_days
{
	echo "${P_NAME}: command: ${FUNCNAME[0]}"

	echo "${P_NAME}: Cleaning up files older than ${BK_KEEP_DAYS} days"

	backup_cleanup_days_func "${BK_TARGET}${BK_NAME}/${BK_TYPE}" ${BK_KEEP_DAYS}

	# database backups will have subdirectories
	find "${BK_TARGET}${BK_NAME}/${BK_TYPE}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | while read DIR
	do
		backup_cleanup_days_func "${BK_TARGET}${BK_NAME}/${BK_TYPE}/${DIR}" ${BK_KEEP_DAYS}
	done
}

function backup_cleanup_days_func
{
	DIR_PATH=$1
	KEEP_DAYS=$2

	find "${DIR_PATH}" -maxdepth 1 -mtime +${KEEP_DAYS} -type f -printf "%f\n"| while read FILE;
	do
		echo "Deleting file ${FILE}"

		rm -f "${DIR_PATH}/${FILE}";
	done
}

function backup_cleanup_numfiles
{
	echo "${P_NAME}: command: ${FUNCNAME[0]}"

	echo "${P_NAME}: Cleaning up files exceeding ${BK_KEEP_NUMFILES} in number"

	backup_cleanup_numfiles_func "${BK_TARGET}${BK_NAME}/${BK_TYPE}" ${BK_KEEP_NUMFILES}

	# database backups will have subdirectories
	find "${BK_TARGET}${BK_NAME}/${BK_TYPE}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | while read DIR
	do
		backup_cleanup_numfiles_func "${BK_TARGET}${BK_NAME}/${BK_TYPE}/${DIR}" ${BK_KEEP_NUMFILES}
	done

}

function backup_cleanup_numfiles_func
{
	DIR_PATH=$1
	KEEP_NUMFILES=$2

	find "${DIR_PATH}" -maxdepth 1 -type f -printf "%f\n"| awk 'NR>'${KEEP_NUMFILES} | while read FILE;
	do
		echo "Deleting file ${FILE}"

		rm -f "${DIR_PATH}/${FILE}";
	done
}
