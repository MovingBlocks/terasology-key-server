# Terasology-key-server [![Build Status](https://travis-ci.org/gianluca-nitti/terasology-key-server.svg?branch=master)](https://travis-ci.org/gianluca-nitti/terasology-key-server)

Web service to store [Terasology](https://github.com/MovingBlocks/Terasology) client identities, powered by PostgreSQL and node.js.

See [this forum thread](http://forum.terasology.org/threads/client-identity-cloud-storage-service.1846/) for more information.

## How to install
This application is designed to be deployed using Docker and docker-compose. These are the only dependencies you need on the server machine. To run the application, look in the .env file at the repository root and consider if it's necessary to override some variables, then run `docker-compose up`; in a production environment, most importantly you need to set the reCAPTCHA keys. It's not necessary to modify the .env file, all the customizations can be passed as environment variables - for example, your startup command may look like `HTTPS_ENABLED=false RECAPTCHA_SITE_KEY=yoursitekey RECAPTCHA_SECRET_KEY=yoursecretkey docker-compose up`.
Two details which is important to note:
- At the moment stopping and re-starting the containers, unfortunately, doesn't bring the application back online correctly. If you stop them, you will need to destroy them (**warning**, please read the next point too). This is due to some initialization steps, required for the database to work correctly, that are in a script which is run only when the container starts for the first time. I'll see if I have time to fix this behaviour.
- Destroying (`docker-compose rm`, `docker rm` or similar) the database container **will destroy the database data too**. If you have relevant data in the database (i.e. some users actually registered and uploaded client identities) you first need to get a shell into the container and export a database dump.

## Credits
This project is made possible by: <a href="https://www.postgresql.org/">PostgreSQL</a>, <a href="https://nodejs.org/">Node.js</a>,
<a href="https://github.com/macek/jquery-serialize-object">jquery-serialize-object</a>, <a href="https://github.com/pramsey/pgsql-http">pgsql-http</a>, <a href="https://github.com/captbrando/pgMail">pgMail</a>,
<a href="https://github.com/gianluca-nitti/terasology-key-server/blob/master/webapp/package.json">All the modules listed in packages.json</a>.
