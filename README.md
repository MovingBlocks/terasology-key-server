# Terasology-key-server [![Build Status](https://travis-ci.org/gianluca-nitti/terasology-key-server.svg?branch=master)](https://travis-ci.org/gianluca-nitti/terasology-key-server)

Web service to store [Terasology](https://github.com/MovingBlocks/Terasology) client identities, powered by PostgreSQL and node.js.

See [this forum thread](http://forum.terasology.org/threads/client-identity-cloud-storage-service.1846/) for more information.

## How to install
This application is designed to be deployed using Docker and docker-compose. These are the only dependencies you need on the server machine. To run the application, look in the .env file at the repository root and consider if it's necessary to override some variables, then run `docker-compose up`; in a production environment, most importantly you need to set the reCAPTCHA keys. It's not necessary to modify the .env file, all the customizations can be passed as environment variables - for example, your startup command may look like `HTTPS_ENABLED=false RECAPTCHA_SITE_KEY=yoursitekey RECAPTCHA_SECRET_KEY=yoursecretkey docker-compose up`.

Note: destroying (`docker-compose rm`, `docker rm` or similar) the database container **will delete the database data too**. If you have relevant data in the database (i.e. some users actually registered and uploaded client identities) you first need to ensure you have an updated backup (see below for more information).

## Starting and stopping
Since v1.1 stopping and restarting the containers (i.e. `docker-compose stop` followed by `docker-compose up`) works correctly. Remember however, that you always need to specify the environment variables you want to override when running `docker-compose up`.

## Backups
Since v1.1 an automated backup script is included. Backups, in the form of SQL database dumps (with data only, no schema), are performed daily at 00:00 and kept for 7 days (meaning you should be able to restore the database at the state of any day in the past week).

The dump files are put in a directory which is shared between the database container and the host machine. By default, the host directory is `./db-dumps`, relative to the directory `docker-compose up` is run from; it's recommended you customize it by overriding the `DB_BACKUP_VOLUME` environment variable (perhaps using an absolute path). Backup files are named in the form `backup_<date and time>.sql`. If an error occurs while performing a backup, a file with the standard error produced by the script is placed in the directory.

See `sql/Dockerfile` and `sql/scripts/backup.sh` for more details.

### Manual backup
It's possible to manually launch a backup by executing the `backup.sh` script placed in the `app-scripts` directory of the database container.
You need to execute the script as the `terasologykeys_backup` user (not as root). In other words, simply use this command:

`docker exec -it terasologykeyserver_database_1 gosu terasologykeys_backup /app-scripts/backup.sh`

You may need to change `terasologykeyserver_database_1` if the container name is different (use `docker ps` to see a list of the running containers).

### Restoring a backup
To restore a backup, ensure there is no database container (if necessary, remove it with `docker rm terasologykeyserver_database_1` or similar, according to the container name, but again **warning: this will destroy the current database**, so ensure your backups are updated to the latest changes if doing this - you probably want to run a manual backup as described above). Then, start the application with `docker-compose up` after setting `DB_RESTORE_BACKUP_FILENAME` to the backup file name you want to restore, which must be in the backups folder (specified by `DB_BACKUP_VOLUME`, default `./db-dumps`). Example:

`DB_RESTORE_BACKUP_FILENAME=backup_2017-08-12T09:48:25+0000.sql [other variables such as reCAPTCHA keys] docker-compose up`

If this variable is set, when the database container is created, it will import the data from the specified file after creating the schema (tables, functions, etc).

## Credits
This project is made possible by: <a href="https://www.postgresql.org/">PostgreSQL</a>, <a href="https://nodejs.org/">Node.js</a>, <a href="https://www.docker.com/">Docker</a>,
<a href="https://github.com/macek/jquery-serialize-object">jquery-serialize-object</a>, <a href="https://github.com/pramsey/pgsql-http">pgsql-http</a>, <a href="https://github.com/asotolongo/pgsmtp">pgsmtp</a>,
<a href="https://github.com/gianluca-nitti/terasology-key-server/blob/master/webapp/package.json">All the modules listed in packages.json</a>.
