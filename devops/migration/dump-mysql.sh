#!/bin/bash

set -e

SITEDIR="/path/to/redmine"
TGZPATH="/path/to/redmine-$(date -u +%Y%m%dT%H%M%SZ).tgz"
DBHOST="localhost"
DBPORT="3306"
DBUSER="redmine_user"
DBNAME="redmine_production"
DBARGS="--ssl --no-tablespaces --complete-insert --password"

symlink() {
    ln -s "$(readlink -f $1)" "$2"
}

TEMPDIR=$(mktemp -d)

mysqldump \
    $DBARGS \
    -h "$DBHOST" \
    -P "$DBPORT" \
    -u "$DBUSER" \
    "$DBNAME" \
    >$TEMPDIR/db.dump

symlink "$SITEDIR/files" "$TEMPDIR/files"
symlink "$SITEDIR/config" "$TEMPDIR/config"
symlink "$SITEDIR/plugins" "$TEMPDIR/plugins"
symlink "$SITEDIR/public" "$TEMPDIR/public"

tar -C $TEMPDIR -f $TGZPATH -czvvh --owner root --group root --mode a+rX,og-w .
