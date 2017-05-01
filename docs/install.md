# Database installation
Two rolse/users are created, one is the administrator of the database and is used to create the tables and stored procedures (to avoid using the root user), the other one will be used by the web application and will only have access to selected stored procedures (no direct access to the data).
* Using the root user, create the "admin" role:
```
user@server:~$ su - postgres
postgres@server:~$ createuser -dPr terasologykeys_admin -U postgres
```
* Enter a (strong) password when prompted. You will need this password to install the database.
* Then, create a database with this user as owner:
```
postgres@server:~$ psql -U postgres -c "CREATE DATABASE terasologykeys WITH OWNER terasologykeys_admin;"
```
* Now, use the admin role to install the database; it's suggested you change the default password for the user which will be added:
```
postgres@server:~$ exit
user@server:~$ cd terasology-key-server/sql
user@server:~/terasology-key-server/sql$ vi 3-app-user.sql
# edit the password now and save the file
user@server:~/terasology-key-server/sql$ cat *.sql | psql -U terasologykeys_admin -d terasologykeys
```
You will probably be asked to enter the password you set for the `terasologykeys_admin` role. You don't need to create the limited user since the last sql file automatically generates it and assigns the correct privileges.
