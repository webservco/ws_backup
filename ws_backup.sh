#!/bin/bash

P_NAME="$(basename $0)"
P_PATH="$(dirname $(readlink -f $0))/"

echo -n "${P_NAME}: "
date "+%Y-%m-%d %H:%M:%S"

# check if configuration file is set
if [ "$1" != "" ]; then

	# check if configuration file exists
	if [ -f "${P_PATH}config/$1.sh" ]; then

		# check if backup_type is set
		if [ "$2" != "" ]; then

				case $2 in
					monthly )
						BK_TYPE="monthly"
						;;
					daily )
						BK_TYPE="daily"
						;;
					* )
						BK_TYPE="daily"
						;;
				esac

				echo "${P_NAME}: type: ${BK_TYPE}"

			# check if command is set
			if [ "$3" != "" ]; then

				. "${P_PATH}lib/functions.sh"

				. "${P_PATH}config/$1.sh"

					case $3 in

						backup_cleanup_days )
							backup_cleanup_days
							;;
						backup_cleanup_numfiles )
							backup_cleanup_numfiles
							;;
						backup_db )
							backup_db
							;;
						backup_fs )
							backup_fs
							;;
						backup_fs_log )
							backup_fs_log
							;;
						* )
							echo "${P_NAME}: error: command not found."
							;;
					esac

				echo "${P_NAME}: done."

			else
				echo "${P_NAME}: error: command is missing."
			fi

		else
			echo "${P_NAME}: error: backup type not set."
		fi

	else
		echo "${P_NAME}: error: configuration file does not exist."
	fi

else
	echo "${P_NAME}: error: configuration file not set"
fi
