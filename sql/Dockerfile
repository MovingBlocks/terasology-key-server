FROM postgres:9.6

# avoid showing docker image default warning, password authentication for root user will be disabled later # TODO do it!
ENV POSTGRES_PASSWORD=no_password_auth

# for mail sender stored procedure
RUN apt-get update && apt-get install -y postgresql-plpython-9.6

# install HTTP extension
WORKDIR /usr/src/pgsql-http
RUN apt-get update && \
	apt-get install -y git build-essential postgresql-server-dev-9.6 postgresql-contrib libcurl4-openssl-dev && \
	git clone https://github.com/pramsey/pgsql-http.git . && make install

# install mail extension (pgsmtp)
WORKDIR /usr/src/pgsmtp
RUN git clone https://github.com/asotolongo/pgsmtp.git . && make install

# remove unnecessary packages
RUN apt-get remove -y git build-essential && apt-get autoremove -y && apt-get clean

# copy SQL files and installer script
WORKDIR /usr/src/app-sql
COPY ./main .
WORKDIR /etc/app-sql
COPY ./default-config.sql ./default-config.sql
WORKDIR /docker-entrypoint-initdb.d
COPY ./docker-setup.sh ./docker-setup.sh
