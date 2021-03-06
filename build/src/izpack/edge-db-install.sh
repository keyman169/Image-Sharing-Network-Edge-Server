#!/bin/bash
echo "executing edge-db-install.sh"

export PGPASSWORD=$DBSUPERPASSWD
DBHOST=$1
DBPORT=$2
SUPERUSER=$3
SQLFILE=$4
TMPPATH=$5
INSTALLER_DBVERSION=${6%-*}
UPGRADE=$7

CURVERSION=`/usr/bin/env psql -w -h $DBHOST -p $DBPORT -U $SUPERUSER rsnadb -At -c "SELECT version FROM schema_version ORDER BY modified_date DESC LIMIT 1"`

export PGOPTIONS='--client-min-messages=warning'

if [ "$UPGRADE" == "1" ] && [ "x$CURVERSION" != "x$INSTALLER_DBVERSION" ]; then # upgrade from previous version
    OLDIFS=$IFS
    IFS=$'\n'
    SQLUPDFILES=$(ls $INSTALL_PATH/RSNADB?rollout*.sql | sort | grep --no-group-separator -A100 "$CURVERSION" | tail -n +2)
    echo "updating schema" $SQLUPDFILES
    sed -e 's/\xef\xbb\xbf//g' $SQLUPDFILES | /usr/bin/env psql -v ON_ERROR_STOP=1 --pset pager=off -q -X -1 -w -h $DBHOST -p $DBPORT -U $SUPERUSER rsnadb || exit 1
    IFS=$OLDIFS
    exit 0
fi

if [ "$UPGRADE" == '0' ]; then
  /usr/bin/env dropuser -w -h $DBHOST -p $DBPORT -U $SUPERUSER edge
  /usr/bin/env dropdb -w -h $DBHOST -p $DBPORT -U $SUPERUSER rsnadb
  echo "creating edge user"
  /usr/bin/env psql -v ON_ERROR_STOP=1 --pset pager=off -X -q -w -h $DBHOST -p $DBPORT -U $SUPERUSER postgres -c "CREATE ROLE edge WITH NOSUPERUSER NOCREATEDB NOCREATEROLE LOGIN ENCRYPTED PASSWORD '$DBPASSWD'" &&
  echo "creating rsnadb database, ignore 'does not exist' errors"
  /usr/bin/env createdb -w -h $DBHOST -p $DBPORT -U $SUPERUSER -O edge rsnadb &&
  /usr/bin/env psql -v ON_ERROR_STOP=1 --pset pager=off -X -q -w -h $DBHOST -p $DBPORT -U $SUPERUSER rsnadb < $SQLFILE || exit 1
  echo "creating admin user to web interface, default password is 'changeme'"
  /usr/bin/env psql -v ON_ERROR_STOP=1 --pset pager=off -X -q -w -h $DBHOST -p $DBPORT -U $SUPERUSER rsnadb <<EOF
INSERT INTO users (user_login, user_name, email, crypted_password, salt, created_at, updated_at, role_id, modified_date)
VALUES ('admin','Admin User','admin@example.com','0265195cc1b2c7ac3160783afb81980920cace88','9faa7cc72fb798a3ca2330a2e4560859abfa0351',now(),now(),2,now());
INSERT INTO configurations (key, value, modified_date) values ('tmp-dir-path','$TMPPATH', now());
EOF
  exit 0
fi

echo "completing edge-db-install.sh"

