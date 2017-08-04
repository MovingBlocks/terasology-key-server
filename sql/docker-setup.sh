#! /bin/bash
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
	echo "CREATE OR REPLACE FUNCTION pg_temp.get_$1() RETURNS TEXT AS \$\$
  		SELECT '$2'::TEXT;
	\$\$ LANGUAGE sql;" >> $CFGOVERRIDEFILE;
}
if [[ -n $RECAPTCHA_SECRET_KEY ]]; then addConfigEntry reCAPTCHA_secret $RECAPTCHA_SECRET_KEY ; fi
if [[ -n $APP_USER_NAME ]]; then addConfigEntry app_user_name $APP_USER_NAME ; fi # No longer configurable because it's stored in firewall (pg_hba.conf)
if [[ -n $APP_USER_PASSWORD ]]; then addConfigEntry app_user_password $APP_USER_PASSWORD ; fi
addConfigEntry batch_user_name terasologykeys_batch
addConfigEntry batch_user_password ""

# uncomment for debug (warning: could show sensitive information like reCAPTCHA secret key and database roles access credentials)
# echo "BEGIN CONFIG OVERRIDE FILE"
# cat $CFGOVERRIDEFILE
# echo "END CONFIG OVERRIDE FILE"

# install database schema and stored procedures as the admin user (not superuser)
cat $CFGDEFAULTFILE $CFGOVERRIDEFILE /usr/src/app-sql/*.sql | psql --username terasologykeys_admin -d terasologykeys

# remove temporary files
rm $CFGOVERRIDEFILE

# set up firewall
if [[ -z $APP_USER_NAME ]]; then APP_USER_NAME=terasologykeys_app; fi
if [[ -z $APP_HOSTNAME ]]; then
	APP_IP="127.0.0.1"
	echo "WARNING: APP_HOSTNAME is not set! Application won't be able to connect."
else
	APP_IP=$(getent hosts $APP_HOSTNAME | cut -d' ' -f1)
fi
cat > /var/lib/postgresql/data/pg_hba.conf <<EOL
local * * reject
host * * * reject
local terasologykeys terasologykeys_batch trust
host terasologykeys $APP_USER_NAME $APP_IP/32 md5
EOL

# apply changes
pg_ctl reload
