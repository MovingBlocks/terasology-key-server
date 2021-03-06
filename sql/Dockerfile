FROM postgres:9.6

# for mail sender stored procedure
RUN apt-get update && apt-get install -y postgresql-plpython-9.6

# install HTTP extension
WORKDIR /usr/src/pgsql-http
RUN apt-get update && \
	apt-get install -y sudo git build-essential postgresql-server-dev-9.6 postgresql-contrib libcurl4-openssl-dev && \
	git clone https://github.com/pramsey/pgsql-http.git . && make install

# install mail extension (pgsmtp)
WORKDIR /usr/src/pgsmtp
RUN git clone https://github.com/asotolongo/pgsmtp.git . && make install

# remove unnecessary packages
RUN apt-get remove -y git build-essential && apt-get autoremove -y && apt-get clean

# set up cron for cleanup of expired sessions and registrations, and automated backups
RUN useradd -r terasologykeys_batch -s /bin/bash && \
	useradd -r terasologykeys_backup -s /bin/bash && \
	echo '0 * * * * terasologykeys_batch psql -d terasologykeys -c "SELECT cleanup_expired_tokens(); " > /dev/null 2>&1' >> /etc/crontab && \
	echo '0 0 * * * terasologykeys_backup bash /app-scripts/backup.sh' >> /etc/crontab

# copy SQL files, init and installer script and backup script
WORKDIR /usr/src/app-sql
COPY ./main .
WORKDIR /etc/app-sql
COPY ./default-config.sql ./default-config.sql
WORKDIR /docker-entrypoint-initdb.d
COPY ./docker-setup.sh ./docker-setup.sh
RUN chmod +x docker-setup.sh && mkdir /app-scripts
WORKDIR /app-scripts
COPY ./scripts ./
RUN chmod +x *.sh 

# override entrypoint to perform various initialization steps (see docker-init.sh)
ENTRYPOINT ["/app-scripts/docker-init.sh"]
