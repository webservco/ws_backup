#!/bin/bash

BK_NAME="mysql"

BK_TARGET='/var/backup/custom/'

BK_KEEP_DAYS='7'

BK_KEEP_NUMFILES='3'

BK_DB_HOST='localhost' # hostname
BK_DB_PORT='3306' # port
BK_DB_USER='' # username
BK_DB_PASS='' #password
BK_DB_IGNORE=(databasename1 databasename2) #ignore databases
