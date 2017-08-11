#! /bin/bash
echo "Performing backup..."
pg_dump -n terasologykeys -a terasologykeys > /var/terasologykeys_backups/backup_$(date -Iseconds).sql 2>/var/terasologykeys_backups/error_$(date -Iseconds)
echo "Deleting empty error logs..."
find /var/terasologykeys_backups -size 0 -name "error_*" -type f -delete
echo "Deleting old backups..."
find /var/terasologykeys_backups -mtime +7 -name "backup_*" -type f -delete
echo "Done."
