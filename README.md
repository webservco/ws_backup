# ws_backup

A Bash backup tool, compatible with ISPConfig servers.

Backs up MySQL/MariaDB and PostgreSQL databases and directories into dated archives, and removes old backups by age or count, driven by cron.

- Requires: Bash, GNU `find`, `tar`, `gzip`, `truncate`, `7z` (p7zip), the MariaDB/MySQL client for `backup_db`, PostgreSQL 14+ client tools for `backup_db_pgsql`

---

## Installation

```shell
cd /opt
git clone https://github.com/webservco/ws_backup.git
chmod +x /opt/ws_backup/ws_backup.sh
mkdir -p /var/backup/ws_backup/
```

Create a config file for each backup from the `.dist` templates in `config/`:

```shell
cd /opt/ws_backup
cp config/mysql.sh.dist config/mysql.sh
cp config/pgsql.sh.dist config/pgsql.sh
```

---

## Usage

```shell
/opt/ws_backup/ws_backup.sh CONFIG_NAME daily|monthly COMMAND
```

`CONFIG_NAME` loads `config/CONFIG_NAME.sh`. Any type other than `monthly` counts as `daily`. Backups go to `${BK_TARGET}${BK_NAME}/${BK_TYPE}/`.

| Command | What it does |
| --- | --- |
| `backup_db` | Dumps each MySQL/MariaDB database to `{db}/{db}_{timestamp}.sql.gz`. Skips `mysql`, `information_schema`, `performance_schema` and `BK_DB_IGNORE`. |
| `backup_db_pgsql` | Same for PostgreSQL, with `pg_dump --clean --if-exists`. Skips template databases and `BK_DB_IGNORE`. Roles and other global objects aren't included. |
| `backup_fs` | Archives `BK_SOURCE` as `tar.gz`. |
| `backup_fs_log` | Zips a log directory with 7z, then deletes its `*.context` files and empties its `*.log` files. |
| `backup_fs_day` | Zips each subdirectory of `BK_SOURCE` except today's (`YYYYMMDD`), moves the zip straight into `BK_TARGET`, then deletes the directory if its name is a date. The type and the cleanup commands don't apply. |
| `backup_cleanup_days` | Deletes backups older than `BK_KEEP_DAYS`. |
| `backup_cleanup_numfiles` | Keeps only the `BK_KEEP_NUMFILES` newest backups. |

### Cron

```shell
# Daily database backups, kept for BK_KEEP_DAYS.
0 1 * * * /opt/ws_backup/ws_backup.sh mysql daily backup_db &>> /var/log/ws_backup_mysql.log
5 1 * * * /opt/ws_backup/ws_backup.sh mysql daily backup_cleanup_days &>> /var/log/ws_backup_mysql.log
# Monthly database backups, keeping the newest BK_KEEP_NUMFILES.
0 1 1 * * /opt/ws_backup/ws_backup.sh mysql monthly backup_db &>> /var/log/ws_backup_mysql.log
5 1 1 * * /opt/ws_backup/ws_backup.sh mysql monthly backup_cleanup_numfiles &>> /var/log/ws_backup_mysql.log
```

For PostgreSQL, use the `pgsql` config and `backup_db_pgsql`.

To archive the daily directories of a `webservco/log` log directory, schedule `backup_fs_day` before the other backups:

```shell
3 0 * * * /opt/ws_backup/ws_backup.sh example_log daily backup_fs_day &>> /var/log/ws_backup.example_log.log
```

---

## Configuration

Each config file is a Bash script that sets `BK_*` variables:

```shell
BK_NAME="mysql"
# Trailing slash required.
BK_TARGET='/var/backup/ws_backup/'
BK_KEEP_DAYS='7'
BK_KEEP_NUMFILES='3'
# File system commands only. Trailing slash required.
BK_SOURCE='/path/to/source/'

# Database commands only.
# Empty host: local unix socket.
BK_DB_HOST='127.0.0.1'
BK_DB_PORT='3306'
# Empty user and password: unix_socket (MySQL) or ~/.pgpass and peer (PostgreSQL) authentication.
BK_DB_USER=''
BK_DB_PASS=''
BK_DB_IGNORE=(databasename1 databasename2)
BK_EXECUTABLE_MYSQL='mariadb'
BK_EXECUTABLE_MYSQLDUMP='mariadb-dump'

# PostgreSQL only.
BK_DB_MAINTENANCE='postgres'
BK_EXECUTABLE_PSQL='psql'
BK_EXECUTABLE_PG_DUMP='pg_dump'
```

Real config files hold credentials and are gitignored. Only the `.dist` templates are committed.

### MySQL user

Grant `SELECT`, `FILE`, `CREATE TEMPORARY TABLES`, `SHOW VIEW`, `EXECUTE`, `TRIGGER` and `RELOAD`.

The credentials go to the client through a temporary `0600` option file passed with `--defaults-file`, so the password doesn't show in the process list. The client reads only that file and ignores `~/.my.cnf` and `/etc/my.cnf`.

### PostgreSQL user

```sql
CREATE ROLE ws_backup LOGIN PASSWORD '...';
GRANT pg_read_all_data TO ws_backup;
```

The user also needs `CONNECT` on every database, which `PUBLIC` has by default. To generate the missing grants:

```sql
SELECT format('GRANT CONNECT ON DATABASE %I TO ws_backup;', datname) FROM pg_database WHERE datallowconn AND NOT datistemplate AND NOT has_database_privilege('ws_backup', oid, 'CONNECT');
```

Instead of `BK_DB_PASS`, you can store the password in `~/.pgpass` (mode `0600`) of the user running cron.

---

## Notes

`backup_fs_log` and `backup_fs_day` delete or empty the source data on purpose. They check that the paths are set, end with a slash and aren't `/`, but a valid path to the wrong directory will still get cleared. `backup_fs_day` only deletes directories named with an 8-digit date, and only when both the zip and the move succeeded.

`BK_KEEP_NUMFILES=0` is accepted and deletes every backup in the target directory.

If one database dump fails, the partial file is deleted and the script carries on with the other databases, then exits with an error.

The `etc` and `var_www` templates back up `/etc` and `/var/www/clients/` with `backup_fs`. They're deprecated. Use [duply](https://duply.net/) instead.

---

## License

[MIT](LICENSE)
