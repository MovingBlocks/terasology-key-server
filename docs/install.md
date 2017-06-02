# Preparation
* Obtain a pair of reCAPTCHA site and secret keys (see [here](http://www.google.com/recaptcha/admin)).
* Replace the test keys with your keys:
  * The site key goes in the `data-sitekey` attribute of the `div` element at line 63 of `webapp/static/register.html`.
  * The secret key goes at the `serial` parameter on line 103 of `sql/1-internal-procedures.sql`.

# Database installation
Two roles/users are created, one is the administrator of the database and is used to create the tables and stored procedures (to avoid using the root user), the other one will be used by the web application and will only have access to selected stored procedures (no direct access to the data).
* Install the following PostgreSQL extensions: [pgmail](https://github.com/captbrando/pgMail) and [pgsql-http](https://github.com/pramsey/pgsql-http); refer to their READMEs for more detailed instructions. When configuring pgmail, you will need to specify an SMTP server; you could install a local one using [postfix](http://www.postfix.org/).
* Using the root user, create the "admin" role:
```
user@server:~$ su - postgres
postgres@server:~$ createuser -dPr terasologykeys_admin -U postgres
```
* Enter a (strong) password when prompted. You will need this password to install the database.
Alternatively, you can use [peer authentication](https://www.postgresql.org/docs/current/static/auth-methods.html#AUTH-PEER).
Refer to the `createuser` [man page](https://www.postgresql.org/docs/current/static/app-createuser.html) for the correct command line options to use.
* Then, create a database with this user as owner:
```
postgres@server:~$ psql -U postgres -c "CREATE DATABASE terasologykeys WITH OWNER terasologykeys_admin;"
```
* While you are connected as superuser, enable the previously installed extensions in the new database, plus `uuid-ossp` and `pgcrypto` extension on this database (this may require to install additional system packages, such as `postgresql-contrib` on Debian).
* Now, use the admin role to install the database; it's suggested you change the default password for the user which will be added:
```
postgres@server:~$ exit
user@server:~$ cd terasology-key-server/sql
user@server:~/terasology-key-server/sql$ vi 3-app-user.sql
# edit the password now and save the file
user@server:~/terasology-key-server/sql$ cat *.sql | PGHOST="localhost" PGPASSWORD="admin-pass" psql -U terasologykeys_admin -d terasologykeys
```
(replace `admin-pass` with the password you entered when asked by `createuser`). You don't need to manually create the limited user since the last sql file automatically generates it and assigns the correct privileges.

# Web application
* If you changed the password for the limited user, edit `webapp/config.json` accordingly. Alternatively, you can copy the configuration to another file, edit it, and then specify the config file when you launch the application with the `--config <file>` command line switch.
* Then, just install the dependencies and run index.js:
```
user@server:~$ cd terasology-key-server/webapp
user@server:~/terasology-key-server/webapp$ npm install
user@server:~/terasology-key-server/webapp$ node index.js
```
* You may consider to run the application as a daemon. If your init system is systemd [this article](https://www.terlici.com/2015/06/20/running-node-forever.html) may be useful.
