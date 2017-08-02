const fs = require('fs');
const path = require('path');
const express = require('express');
const app = express();
const ajv = require('ajv')({allErrors: true});
const bodyParser = require('body-parser');
const statusCodes = require('builtin-status-codes');
const expressPostgresModule = require('express-postgres-sp');
const schemaLoader = require(path.join(__dirname, 'schemaLoader'));
const cors = require('cors');

const noToken = JSON.parse(fs.readFileSync(path.join(__dirname, 'no-token.json')));
const apiPaths = ['/api/:resource', '/api/:resource/:argument'];

module.exports = (dbConfig, redirectHttpToHttps, httpsPort) => {
  const expressPostgres = expressPostgresModule(dbConfig);
  const schemaFiles = schemaLoader.list();
  const schemaList = schemaLoader.names(schemaFiles);
  schemaLoader.load(schemaFiles, ajv);

  if (redirectHttpToHttps) {
    app.use((req, res, next) => {
      if(!req.secure) {
        let host = req.get('Host');
        host = host.substring(0, host.indexOf(':')); // remove HTTP port number
        if (httpsPort !== undefined) { // if not using default port, append port number
           host += ':' + httpsPort;
        }
        return res.redirect(['https://', host, req.url].join(''));
      }
      next();
    });
  }

  //Allow Cross-Origin requests (API calls from browsers on any domain)
  app.use(cors());
  //Enable CORS preflight
  app.options('*', cors());

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
    const argumentSpecificSchemaName = baseSchemaName + (req.params.argument === undefined ? '_0' : '_1');
    if(schemaList.indexOf(baseSchemaName) > -1){
      if(ajv.validate(baseSchemaName, req.body))
        next();
      else
        res.status(400).json({error: 'JSON data validation against schema ' + baseSchemaName + ' failed'});
    }else if(schemaList.indexOf(argumentSpecificSchemaName) > -1){
      if(ajv.validate(argumentSpecificSchemaName, req.body))
        next();
      else
        res.status(400).json({error: 'JSON data validation against schema ' + argumentSpecificSchemaName + ' failed'});
    }else{
      if(Object.keys(req.body).length === 0)
        next();
      else
        res.status(400).json({error: 'Request to the specified endpoint with the specified method must not send any payload'});
    }
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

  //serve the frontend
  app.use('/static', express.static(path.join(__dirname, 'static')));
  app.get('/', (req, res) => res.redirect('/static/register.html'));

  return app;
};
