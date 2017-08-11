#! /bin/bash

# This script is only ran when the database needs to be initialized (when the container is started after being created).

set -e

# set up admin user (peer authentication only)
createuser -dwr terasologykeys_admin --username "$POSTGRES_USER"

# create the database
createdb terasologykeys -O terasologykeys_admin --username "$POSTGRES_USER"

# install extensions in database
psql --username "$POSTGRES_USER" -d terasologykeys -c "CREATE LANGUAGE plpythonu; CREATE EXTENSION pgcrypto; CREATE EXTENSION http; CREATE EXTENSION pgsmtp;"

# setup SMTP server
if [[ -z $SMTP_PORT ]]; then SMTP_PORT=25; fi
psql --username "$POSTGRES_USER" -d terasologykeys -c "INSERT INTO pgsmtp.user_smtp_data VALUES ('$SMTP_USER', '$SMTP_SERVER', $SMTP_PORT, '$SMTP_PASS'); GRANT USAGE ON SCHEMA pgsmtp TO terasologykeys_admin; GRANT SELECT ON pgsmtp.user_smtp_data TO terasologykeys_admin; "

# override configuration according to env variables
CFGDEFAULTFILE=/etc/app-sql/default-config.sql
CFGOVERRIDEFILE=/tmp/override-config.sql
touch $CFGOVERRIDEFILE
truncate -s 0 $CFGOVERRIDEFILE
function addConfigEntry {
	echo "CREATE OR REPLACE FUNCTION $1() RETURNS TEXT AS \$\$
  		SELECT '$2'::TEXT;
	\$\$ LANGUAGE sql;" >> $CFGOVERRIDEFILE;
}
if [[ -n $RECAPTCHA_SECRET_KEY ]]; then addConfigEntry config.get_reCAPTCHA_secret $RECAPTCHA_SECRET_KEY ; fi
if [[ -n $APP_USER_NAME ]]; then addConfigEntry pg_temp.get_app_user_name $APP_USER_NAME ; fi
if [[ -n $APP_USER_PASSWORD ]]; then addConfigEntry pg_temp.get_app_user_password $APP_USER_PASSWORD ; fi
addConfigEntry pg_temp.get_batch_user_name terasologykeys_batch
addConfigEntry pg_temp.get_batch_user_password ""
addConfigEntry pg_temp.get_backup_user_name terasologykeys_backup
addConfigEntry pg_temp.get_backup_user_password ""

# uncomment for debug (warning: could show sensitive information like reCAPTCHA secret key and database roles access credentials)
# echo "BEGIN CONFIG OVERRIDE FILE"
# cat $CFGOVERRIDEFILE
# echo "END CONFIG OVERRIDE FILE"

# install database schema and stored procedures as the admin user (not superuser)
cat $CFGDEFAULTFILE $CFGOVERRIDEFILE /usr/src/app-sql/*.sql | psql --username terasologykeys_admin -d terasologykeys

# remove temporary files
rm $CFGOVERRIDEFILE

# restore backup if required
if [[ -n $RESTORE_BACKUP_FILENAME ]]; then
	cat /var/terasologykeys_backups/$RESTORE_BACKUP_FILENAME | psql --username terasologykeys_admin -d terasologykeys
fi

# set up firewall (pg_hba.conf)
source /app-scripts/setup-firewall.sh
pg_ctl reload
