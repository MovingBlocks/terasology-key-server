const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

let configFile = path.join(__dirname, 'config.json');
const configArg = process.argv.indexOf('--config');
if (configArg > -1)
  configFile = process.argv[configArg + 1];
const config = JSON.parse(fs.readFileSync(configFile));

const createApp = require(path.join(__dirname, 'server-lib'));
let app;

switch (config.http.mode) {
  case "preserveHttp":
    app = createApp(config.db, false);
    break;
  case "redirectToHttpsConfiguredPort":
    app = createApp(config.db, true, config.https.port);
    break;
  case "redirectToHttpsDefaultPort":
    app = createApp(config.db, true);
    break;
  default:
    console.warn('Invalid HTTP mode in configuration - valid values are "enabled", "disabled", "redirectToHTTPS"');
    process.exit(1);
}

http.createServer(app).listen(config.http.port, () => console.log('HTTP Server listening'));

if (config.https.enabled) {
  const options = {
    key: fs.readFileSync(config.https.keyFile),
    cert: fs.readFileSync(config.https.certFile)
  };
  https.createServer(options, app).listen(config.https.port, () => console.log('HTTPS server listening'));
}
