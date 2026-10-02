# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`ws_backup` is a small Bash backup system (ISPConfig-compatible) meant to be cloned to `/opt/ws_backup` on a server and driven by cron. There is no build step, test suite, or linter configured. `shellcheck ws_backup.sh lib/functions.sh` is a reasonable check if available, but it isn't part of the project.

## Invocation

```sh
/opt/ws_backup/ws_backup.sh <config_name> <daily|monthly> <command>
```

- `<config_name>` → sources `config/<config_name>.sh` (resolved relative to the script's real path).
- `<daily|monthly>` → sets `BK_TYPE`. Any other value silently falls back to `daily`.
- `<command>` → one of the functions in `lib/functions.sh`: `backup_db`, `backup_db_pgsql`, `backup_fs`, `backup_fs_log`, `backup_fs_day`, `backup_cleanup_days`, `backup_cleanup_numfiles`.

All output goes to stdout. Cron redirects it into `/var/log/ws_backup*.log` (see README for the cron examples). Errors are echoed messages, not non-zero exit codes.

## Architecture

- `ws_backup.sh` is the dispatcher. It validates its args, sources `lib/functions.sh`, then sources the config file, then calls the function picked by the `case` statement. **Adding a new command means adding a function in `lib/functions.sh` and a matching `case` branch in `ws_backup.sh`.**
- Config files are plain Bash that set `BK_*` globals, which the functions read directly: `BK_NAME`, `BK_TARGET` (needs a trailing slash), `BK_SOURCE`, `BK_KEEP_DAYS`, `BK_KEEP_NUMFILES`. DB configs also set `BK_DB_HOST/PORT/USER/PASS`, the `BK_DB_IGNORE` array, and `BK_EXECUTABLE_MYSQL`/`BK_EXECUTABLE_MYSQLDUMP` (default `mariadb`/`mariadb-dump`). PostgreSQL configs (`config/pgsql.sh.dist`) use the same `BK_DB_*` names plus `BK_DB_MAINTENANCE` and `BK_EXECUTABLE_PSQL`/`BK_EXECUTABLE_PG_DUMP`.
- `config/` is gitignored except `*.dist` templates and `.gitignore`. Real configs (which contain DB credentials) stay on the server and must never be committed.

### Output layout and cleanup coupling

Most commands write to `${BK_TARGET}${BK_NAME}/${BK_TYPE}/`:
- `backup_fs`: `tar.gz` of `BK_SOURCE`.
- `backup_fs_log`: 7z-compressed `.zip` of a WSFW log dir. It then **deletes `*.context` files and truncates `*.log` files in the source**.
- `backup_db`: one subdirectory per database (`.../<db>/<db>_<timestamp>.sql.gz`). It skips `mysql`, `information_schema`, `performance_schema` and anything in `BK_DB_IGNORE`. If listing the databases fails it returns 1; if one dump fails it deletes that partial file, continues with the next database and returns 1 at the end.
- `backup_db_pgsql`: same layout as `backup_db`, so the cleanup commands work unchanged. It lists databases from `pg_database` (templates excluded), passes the password through `PGPASSWORD` (empty = `~/.pgpass`/peer auth, empty host = unix socket), and dumps with `pg_dump --clean --if-exists` piped to gzip. Error handling is the same as `backup_db`.

The cleanup commands (`backup_cleanup_days` by mtime, `backup_cleanup_numfiles` keeping the N newest files by mtime) work on that same `${BK_TARGET}${BK_NAME}/${BK_TYPE}/` dir plus one level of subdirectories, which is how they handle the per-DB layout.

`backup_fs_day` is different. It processes each subdirectory of `BK_SOURCE` except today's (`YYYYMMDD`) one at a time: zip it, move the zip directly into `BK_TARGET` (no `BK_NAME/BK_TYPE` subpath), then `rm -rf` the source directory, but only if both steps succeeded and the name is an 8-digit date. Non-date directories are archived but kept. `BK_TYPE` has no effect on it, and the cleanup commands do not apply to its output. The README says to schedule it before the other backups.

### Safety checks

Commands that delete files (`backup_fs_day`, `backup_fs_log`, both cleanups) begin by calling the `validate_*` helpers at the top of `lib/functions.sh`. These require path settings to be set, end with a slash and not be `/`, and the keep values to be integers. A function returns 1 on failure, and `ws_backup.sh` then exits non-zero with `finished with errors.` Any new destructive command should call these helpers too. `backup_fs_log` clears its source only when `7z` exits 0.

### Gotchas

- `BK_KEEP_NUMFILES=0` is accepted and deletes every backup in the target directory.
- `BK_EXECUTABLE_MYSQL`/`BK_EXECUTABLE_MYSQLDUMP`/`BK_EXECUTABLE_PSQL`/`BK_EXECUTABLE_PG_DUMP` are deliberately unquoted so they can include extra arguments.
- `backup_fs_log` and `backup_fs_day` delete or empty source data by design. The checks only catch missing or malformed settings: a real but wrong `BK_SOURCE` still gets cleared. Treat changes to these functions as production-risky.
- External tools needed: `7z` (p7zip), `tar`, `gzip`, `find`/`truncate` (GNU), and the MariaDB/MySQL client.

## Conventions

- Indent with 4 spaces, never tabs.
- Each command function starts with `echo "${P_NAME}: command: ${FUNCNAME[0]}"`.
- The `/etc` and `/var/www` backups (`etc`, `var_www` configs) are documented as deprecated in favour of duply.
