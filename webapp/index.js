const fs = require('fs');
const path = require('path');

const config = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json')));

const app = require('express')();
const bodyParser = require('body-parser');
const expressPostgres = require('express-postgres-sp')(config.db);

app.use(bodyParser.json());
//app.use((req, res, next) => {console.log(req.body); next();}); //TODO remove (logging)
app.all(['/api/:resource', '/api/:resource/:argument'], expressPostgres({
  reqToSPName: req => req.method + '_' + req.params.resource,
  inputMode: req => (req.params.argument !== undefined ?
    {body: req.body, urlArgument: req.params.argument} : {body: req.body}),
  outputMode: (spName, result, res) => {
    const val = result.rows[0][spName.toLowerCase()];
    return val ? res.json(val) : res.end();
  }
}));
app.listen(config.listenPort, () => console.log("Server listening"));
