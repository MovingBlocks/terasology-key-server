const fs = require('fs');
const path = require('path');
const ajv = require('ajv')({allErrors: true});
const request = require('supertest');
const tap = require('tap');

const config = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json')));
const app = require(path.join(__dirname, 'server-lib'))(config.db);
const schemaLoader = require(path.join(__dirname, 'schemaLoader'));

const schemaFiles = schemaLoader.list();
const schemaList = schemaLoader.names(schemaFiles);
schemaLoader.load(schemaFiles, ajv);
console.log('Loaded schemas: ' + schemaList);

//Integration test to simulate a normal usage scenario
const testRequests = [
  {method: "post", endpoint: "user_account", argument: null, data: {login: "test", password1: "a", password2: "a"}, expectedStatus: 200, expectedData: null, description: 'ok registration'},
  {method: "post", endpoint: "session", argument: null, data: {login: "test", password: "a"}, expectedStatus: 200, expectedData: null, description: 'ok login'}
];

tap.plan(testRequests.length);

const validate = (schemaName, data, description) => {
  tap.ok(ajv.validate(schemaName, data), 'validate JSON of "' + description + '"');
};

const nextTest = (i) => {
  if (i >= testRequests.length)
    return;
  const testData = testRequests[i];
  const path = '/api/' + testData.endpoint + (testData.argument === null ? '' : '/' + testData.argument);
  let req = request(app);
  switch(testData.method) {
    case 'get': req = req.get(path); break;
    case 'post': req = req.post(path); break;
    case 'delete': req = req.delete(path); break;
    default: throw 'Unsupported method';
  }
  if(testData.data !== null)
    req = req.send(testData.data);
  req.expect(testData.expectedStatus);
  if(testData.expectedData !== null)
    req.expect(testData.expectedData);
  req.end((err, res) => {
    if(err)
      tap.fail('Test "' + testData.description + '" failed with: ' + err.message);
    else {
      const baseSchemaName = 'response_' + testData.method + '_' + testData.endpoint;
      if(schemaList.indexOf(baseSchemaName) > -1)
        validate(baseSchemaName, res.body, testData.description);
      else
        tap.deepEqual(res.body, {});
      //tap.pass('Test "' + testData.description + '" passed');
    }
    nextTest(i + 1);
  });
};
nextTest(0);
