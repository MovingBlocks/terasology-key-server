#! /bin/bash

# This script is always ran when the container is started (first start or restart).

set -e

# rebuild pg_hba.conf if this is not the first start (web application container's IP address might have changed)
# on the first start this can't be done before starting postgres, otherwise it won't start because the data directory is not empty
# so it's done when it's already running (see docker-setup.sh)
if [ -f /var/lib/postgresql/data/pg_hba.conf ]; then source /app-scripts/setup-firewall.sh; fi

# fix permissions for backups volume
chown terasologykeys_backup:terasologykeys_backup /var/terasologykeys_backups

# start crontab daemon (will fork and return)
echo "Starting cron..."
cron
echo "Done."

# start postgres, running install script if it's the first time (docker-entrypoint.sh is installed by the parent postgres image)
echo "Starting postgres..."
docker-entrypoint.sh postgres
