#! /bin/bash
set -e

CFGDIR=/etc/app/
CFGFILE=config.json
STATICDIR=/var/app-static

mkdir -p $CFGDIR
CFGPATH=$CFGDIR$CFGFILE
cp config.json $CFGPATH

mkdir -p $STATICDIR
cp -r static/* $STATICDIR
json -f $CFGPATH -Ie 'this.staticFiles.rootDir="'$STATICDIR'"'
if [[ -n $RECAPTCHA_SITE_KEY ]]; then
	sed -i -e 's/6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI/'$RECAPTCHA_SITE_KEY'/g' $STATICDIR/register.html;
fi

if [[ -n $HTTP_MODE ]]; then json -f $CFGPATH -Ie 'this.http.mode="'$HTTP_MODE'"'; fi
if [[ -n $HTTP_PORT ]]; then json -f $CFGPATH -Ie 'this.http.port='$HTTP_PORT; fi

if [[ -n $HTTPS_PORT ]]; then json -f $CFGPATH -Ie 'this.https.port='$HTTPS_PORT; fi
if [[ -n $HTTPS_ENABLED ]]; then json -f $CFGPATH -Ie 'this.https.enabled='$HTTPS_ENABLED; fi
if [[ -n $HTTPS_KEYFILE ]]; then json -f $CFGPATH -Ie 'this.https.keyFile="'/etc/app/certificates/$HTTPS_KEYFILE'"'; fi
if [[ -n $HTTPS_CERTFILE ]]; then json -f $CFGPATH -Ie 'this.https.keyFile="'/etc/app/certificates/$HTTPS_CERTFILE'"'; fi

if [[ -n $DB_HOST ]]; then json -f $CFGPATH -Ie 'this.db.host="'$DB_HOST'"'; fi
if [[ -n $DB_PORT ]]; then json -f $CFGPATH -Ie 'this.db.port="'$DB_PORT'"'; fi
if [[ -n $DB_NAME ]]; then json -f $CFGPATH -Ie 'this.db.database="'$DB_NAME'"'; fi
if [[ -n $DB_USER ]]; then json -f $CFGPATH -Ie 'this.db.user="'$DB_USER'"'; fi
if [[ -n $DB_PASSWORD ]]; then json -f $CFGPATH -Ie 'this.db.password="'$DB_PASSWORD'"'; fi

node server.js --config $CFGPATH
