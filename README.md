# ws_backup

Simple bash backup system compatible with ISPConfig

---

## Setup

### Create MySQL user

Privileges:
* Data: `SELECT`, `FILE`
* Structure: `CREATE TEMPORARY TABLES`, `SHOW VIEW`, `EXECUTE`, `TRIGGER`
* Administration: `RELOAD`

### Install

```sh
cd /opt
git clone https://github.com/webservco/ws_backup.git
chmod +x /opt/ws_backup/ws_backup.sh
touch /var/log/ws_backup.log
```

### Edit settings
```sh
vim /opt/ws_backup/config/mysql.sh
```

---

## Usage

```sh
mkdir -p /var/backup/custom/
```

### Example cron configuration

#### Backup all MySQL databases

```sh
# ws_backup mysql daily
0 2 * * * /opt/ws_backup/ws_backup.sh mysql daily backup_db &>> /var/log/ws_backup.log
5 2 * * * /opt/ws_backup/ws_backup.sh mysql daily backup_cleanup_days &>> /var/log/ws_backup.log
# ws_backup mysql monthly
0 2 1 * * /opt/ws_backup/ws_backup.sh mysql monthly backup_db &>> /var/log/ws_backup.log
5 2 1 * * /opt/ws_backup/ws_backup.sh mysql monthly backup_cleanup_numfiles &>> /var/log/ws_backup.log
```

#### Backup `/etc` directory (Deprecated)
```sh
# ws_backup etc daily
0 2 * * * /opt/ws_backup/ws_backup.sh etc daily backup_fs &>> /var/log/ws_backup.log
1 2 * * * /opt/ws_backup/ws_backup.sh etc daily backup_cleanup_days &>> /var/log/ws_backup.log
```

#### Backup `/var/www` directory (Deprecated)

```sh
# ws_backup var_www daily
30 3 * * * /opt/ws_backup/ws_backup.sh var_www daily backup_fs &>> /var/log/ws_backup.log
50 3 * * * /opt/ws_backup/ws_backup.sh var_www daily backup_cleanup_days &>> /var/log/ws_backup.log
```
