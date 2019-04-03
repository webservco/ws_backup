#!/bin/bash

# $Id: functions.sh 62 2013-05-29 16:33:12Z radu $

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

function backup_db
{
        echo "${P_NAME}: command: ${FUNCNAME[0]}"

        echo "show databases;" | mysql -h ${BK_DB_HOST} -P ${BK_DB_PORT} -u ${BK_DB_USER} -p${BK_DB_PASS} -N | while read DB_NAME;
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

                                mysqldump -h ${BK_DB_HOST} -P ${BK_DB_PORT} -u ${BK_DB_USER} -p${BK_DB_PASS} --lock-all-tables --complete-insert --add-drop-table ${DB_NAME} | gzip -c > "${DIR}${DB_NAME}_`date "+%y%m%d-%H%M%S"`.sql.gz"
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
