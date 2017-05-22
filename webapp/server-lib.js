const fs = require('fs');
const path = require('path');
const app = require('express')();
const ajv = require('ajv')({allErrors: true});
const bodyParser = require('body-parser');
const statusCodes = require('builtin-status-codes');
const expressPostgresModule = require('express-postgres-sp');
const schemaLoader = require(path.join(__dirname, 'schemaLoader'));

const noToken = JSON.parse(fs.readFileSync('no-token.json'));
const apiPaths = ['/api/:resource', '/api/:resource/:argument'];

module.exports = (dbConfig) => {
  const expressPostgres = expressPostgresModule(dbConfig);
  const schemaFiles = schemaLoader.list();
  const schemaList = schemaLoader.names(schemaFiles);
  schemaLoader.load(schemaFiles, ajv);

  //Request header validation
  app.all(apiPaths, (req, res, next) => {
    const wantToken = noToken.find(item => item.method === req.method.toLowerCase() && item.resource === req.params.resource) === undefined;
    const haveToken = req.get('Session-Token') !== undefined;
    if(wantToken && !haveToken)
      res.status(403).json({error: 'A session token header is required.'});
    else if (!wantToken && haveToken)
      res.status(400).json({error: 'A session token header must not be sent for this endpoint.'});
    else
      next();
  });

  //Request payload parsing
  app.use(bodyParser.json());

  //Request payload validation
  app.all(apiPaths, (req, res, next) => {
    const baseSchemaName = 'request_' + req.method.toLowerCase() + '_' + req.params.resource;
    if(schemaList.indexOf(baseSchemaName) > -1){
      if(ajv.validate(baseSchemaName, req.body))
        next();
      else
        res.status(400).json({error: 'JSON data validation against schema ' + baseSchemaName + ' failed'});
    }else
      if(Object.keys(req.body).length === 0)
        next();
      else
        res.status(400).json({error: 'Request to the specified endpoint with the specified method must not send any payload'});
  });

  //DBMS query
  app.all(apiPaths, expressPostgres({
    reqToSPName: req => req.method + '_' + req.params.resource,
    hideUnallowed: true,
    endOnError: false,
    inputMode: req => {
      const spArgs = {body: req.body};
      if (req.get('Session-Token') !== undefined) spArgs.sessionToken = req.get('Session-Token');
      if (req.params.argument !== undefined) spArgs.urlArgument = req.params.argument;
      return spArgs;
    },
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

  //serve the simple HTML registration page
  app.get('/', (req, res) => res.sendFile(path.join(__dirname, '/static/register.html')));

  return app;
};
