const fs = require('fs');
const path = require('path');

const config = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json')));

const app = require('express')();
const bodyParser = require('body-parser');
const expressPostgres = require('express-postgres-sp')(config.db);

app.use(bodyParser.json());
app.all(['/api/:resource', '/api/:resource/:argument'], expressPostgres({
  reqToSPName: req => req.method + '_' + req.params.resource,
  inputMode: req => {
    if(req.params.argument !== undefined)
      req.body.urlArgument = req.params.argument;
    return req.body;
  },
  outputMode: 'jsonString'
}));
app.listen(config.listenPort, () => console.log("Server listening"));
