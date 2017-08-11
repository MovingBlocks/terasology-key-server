#!/bin/bash

echo "Setting up postgres firewall (pg_hba.conf)..."
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
local terasologykeys terasologykeys_batch peer
local terasologykeys terasologykeys_backup peer
host terasologykeys $APP_USER_NAME $APP_IP/32 md5
EOL
echo "Done."
