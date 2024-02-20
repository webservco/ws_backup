# ws_backup

Simple bash backup system compatible with ISPConfig

---

## Setup

### Create MySQL user (if using database backups)

Privileges:
* Data: `SELECT`, `FILE`
* Structure: `CREATE TEMPORARY TABLES`, `SHOW VIEW`, `EXECUTE`, `TRIGGER`
* Administration: `RELOAD`

### Install

```sh
cd /opt
git clone https://github.com/webservco/ws_backup.git
chmod +x /opt/ws_backup/ws_backup.sh
```

### Edit settings
```sh
cd /opt/ws_backup
cp config/etc.sh.dist config/etc.sh
cp config/mysql.sh.dist config/mysql.sh

vim /opt/ws_backup/config/etc.sh
vim /opt/ws_backup/config/mysql.sh
```

---

## Usage

```sh
mkdir -p /var/backup/ws_backup/
```

### Example cron configurations

#### Backup all MySQL databases

```sh
# ws_backup mysql daily
0 1 * * * /opt/ws_backup/ws_backup.sh mysql daily backup_db &>> /var/log/ws_backup_mysql.log
5 1 * * * /opt/ws_backup/ws_backup.sh mysql daily backup_cleanup_days &>> /var/log/ws_backup_mysql.log
# ws_backup mysql monthly
0 1 1 * * /opt/ws_backup/ws_backup.sh mysql monthly backup_db &>> /var/log/ws_backup_mysql.log
5 1 1 * * /opt/ws_backup/ws_backup.sh mysql monthly backup_cleanup_numfiles &>> /var/log/ws_backup_mysql.log
```

#### Backup WSFW `log` directory

Example configuration:

```shell
vim config/pv3_admin_log.sh

#!/bin/bash

BK_NAME="pv3_admin_log"

BK_TARGET='/var/backup/logs/'

BK_KEEP_DAYS='30'

BK_KEEP_NUMFILES='30'

BK_SOURCE='/PATH/TO/var/log/' #fs
```

Backup:

```shell
# ws_backup pv3_admin_log daily
30 3 * * * /opt/ws_backup/ws_backup.sh pv3_admin_log daily backup_fs_log &>> /var/log/ws_backup.pv3_admin_log.log
50 3 * * * /opt/ws_backup/ws_backup.sh pv3_admin_log daily backup_cleanup_days &>> /var/log/ws_backup.pv3_admin_log.log
55 3 * * * /opt/ws_backup/ws_backup.sh pv3_admin_log daily backup_cleanup_numfiles &>> /var/log/ws_backup.pv3_admin_log.log
```

#### Backup `/etc` directory (Deprecated, use duply)
```sh
# ws_backup etc daily
0 1 * * * /opt/ws_backup/ws_backup.sh etc daily backup_fs &>> /var/log/ws_backup_etc.log
1 1 * * * /opt/ws_backup/ws_backup.sh etc daily backup_cleanup_days &>> /var/log/ws_backup_etc.log
```

#### Backup `/var/www` directory (Deprecated, use duply)

```sh
# ws_backup var_www daily
30 2 * * * /opt/ws_backup/ws_backup.sh var_www daily backup_fs &>> /var/log/ws_backup_www.log
50 2 * * * /opt/ws_backup/ws_backup.sh var_www daily backup_cleanup_days &>> /var/log/ws_backup_www.log
```
