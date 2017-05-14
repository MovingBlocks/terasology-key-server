const fs = require('fs');
const path = require('path');
const config = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json')));

const app = require(path.join(__dirname, 'server-lib'))(config.db);
app.listen(config.listenPort, () => console.log('Server listening'));
