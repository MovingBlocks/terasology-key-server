const path = require('path');
const app = require('express')();
const ajv = require('ajv')({allErrors: true});
const bodyParser = require('body-parser');
const statusCodes = require('builtin-status-codes');
const expressPostgresModule = require('express-postgres-sp');
const schemaLoader = require(path.join(__dirname, 'schemaLoader'));

const apiPaths = ['/api/:resource', '/api/:resource/:argument'];

module.exports = (dbConfig) => {
  const expressPostgres = expressPostgresModule(dbConfig);
  const schemaFiles = schemaLoader.list();
  const schemaList = schemaLoader.names(schemaFiles);
  schemaLoader.load(schemaFiles, ajv);

  app.use(bodyParser.json());
  app.all(apiPaths, (req, res, next) => {
    const baseSchemaName = 'request_' + req.method.toLowerCase() + '_' + req.params.resource.toLowerCase();
    let ok;
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

  return app;
};
