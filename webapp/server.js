const fs = require('fs');
const path = require('path');

let configFile = path.join(__dirname, 'config.json');
const configArg = process.argv.indexOf('--config');
if (configArg > -1)
  configFile = process.argv[configArg + 1];
const config = JSON.parse(fs.readFileSync(configFile));

const app = require(path.join(__dirname, 'server-lib'))(config.db);
app.listen(config.listenPort, () => console.log('Server listening'));
