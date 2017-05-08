const fs = require('fs');
const path = require('path');

const config = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json')));
const apiPaths = ['/api/:resource', '/api/:resource/:argument'];

const app = require('express')();
const bodyParser = require('body-parser');
const statusCodes = require('builtin-status-codes');
const expressPostgres = require('express-postgres-sp')(config.db);

app.use(bodyParser.json());
app.all(apiPaths, expressPostgres({
  reqToSPName: req => req.method + '_' + req.params.resource,
  hideUnallowed: true,
  endOnError: false,
  inputMode: req => (req.params.argument !== undefined ?
    {body: req.body, urlArgument: req.params.argument} : {body: req.body}),
  outputMode: (spName, result, res) => {
    const val = result.rows[0][spName.toLowerCase()];
    return val ? res.json(val) : res.end();
  }
}));
//if the DBMS returns an error, express-postgres-sp will call the next middleware function
app.all(apiPaths, (req, res) => {
  const err = res.locals.sqlError;
  if(err.toString() === 'error: customError'){
    const errData = JSON.parse(err.detail);
    res.status(errData.status).json({error: errData.message});
  } else {
    //status code already set by express-postgres-sp according to SQLstate
    res.json({error: statusCodes[res.statusCode]});
  }
});
app.listen(config.listenPort, () => console.log("Server listening"));
