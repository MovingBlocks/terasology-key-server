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

const user1_id1 = {"server": {"id": "ce49c253-1065-4dc0-a11b-fc06f16379ef","modulus": "YWJj","exponent": "ZGVm","signature": "Z2hp"},
      "clientPublic": {"id": "d2c8637a-7416-47f5-badb-5b77dba50e68", "modulus": "MTIz","exponent": "NDU2","signature": "Nzg5"},
      "clientPrivate": {"modulus": "cHJ2MQ==", "exponent": "cHJ2Mg=="}};
const user1_id2 = {"server": {"id": "74c2c0c4-851c-4e95-9690-13e1fb3c0eac","modulus": "MzMz","exponent": "MjIy","signature": "MTEx"},
      "clientPublic": {"id": "9d355883-ee55-435e-8f0f-13829e83958d","modulus": "YWFh","exponent": "YmJi","signature": "Y2Nj"},
      "clientPrivate": {"modulus": "cHJ2Mw==","exponent": "cHJ2NA=="}};
const user2_id1 = {"server": {"id": "ce49c253-1065-4dc0-a11b-fc06f16379ef","modulus": "YWJj","exponent": "ZGVm","signature": "Z2hp"},
      "clientPublic": {"id": "ae2130bf-6fe0-480f-b59a-62488766edb8", "modulus": "YWJjZA==","exponent": "ZGVmZw==","signature": "aWprbA=="},
      "clientPrivate": {"modulus": "prv1", "exponent": "prv2"}};

//Integration test to simulate a normal usage scenario
let user1Tok, user2Tok;
const testRequests = [
  {method: 'post', endpoint: 'user_account', token: null, argument: null, data: {login: 'a', password1: 'abcdefgh', password2: 'abcdefgh'}, expectedStatus: 400, expectedData: null, description: 'login too short'},
  {method: 'post', endpoint: 'user_account', token: null, argument: null, data: {login: 'thisStringIsVeryLongLongerThan40Characters', password1: 'abcdefgh', password2: 'abcdefgh'}, expectedStatus: 400, expectedData: null, description: 'login too long'},
  {method: 'post', endpoint: 'user_account', token: null, argument: null, data: {login: ' invalid.#$chars', password1: 'abcdefgh', password2: 'abcdefgh'}, expectedStatus: 400, expectedData: null, description: 'invalid characters in login name'},
  {method: 'post', endpoint: 'user_account', token: null, argument: null, data: {login: 'test', password1: 'a', password2: 'a'}, expectedStatus: 400, expectedData: null, description: 'password too short'},
  {method: 'post', endpoint: 'user_account', token: null, argument: null, data: {login: 'test', password1: 'abcdefgh', password2: 'aaaaaaaa'}, expectedStatus: 400, expectedData: null, description: 'unmatching passwords'},
  {method: 'post', endpoint: 'user_account', token: null, argument: null, data: {login: 'user1', password1: 'abcdefgh', password2: 'abcdefgh'}, expectedStatus: 200, expectedData: null, description: 'ok registration user1'},
  {method: 'post', endpoint: 'user_account', token: null, argument: null, data: {login: 'user1', password1: 'abcdefgh', password2: 'abcdefgh'}, expectedStatus: 409, expectedData: null, description: 'duplicated username'},
  {method: 'post', endpoint: 'session', token: null, argument: null, data: {login: 'user1', password: 'abcdefgh'}, expectedStatus: 200, expectedData: null, description: 'ok login', callback: data => user1Tok = data.token},
  () => ({method: 'get', endpoint: 'session', token: user1Tok, argument: null, data: null, expectedStatus: 200, expectedData: {'login': 'user1'}, description: 'get login name from session token'}),
  () => ({method: 'get', endpoint: 'client_identity', token: null, argument: null, data: null, expectedStatus: 403, expectedData: null, description: 'must not be able to get client identities without a session token'}),
  () => ({method: 'get', endpoint: 'client_identity', token: user1Tok, argument: null, data: null, expectedStatus: 200, expectedData: {clientIdentities: []}, description: 'no client identities for newly registered user'}),
  () => ({method: 'post', endpoint: 'client_identity', token: null, argument: null, data: {clientIdentity: user1_id1}, expectedStatus: 403, expectedData: null, description: 'must not be able to upload a client identity without a session token'}),
  () => ({method: 'post', endpoint: 'client_identity', token: user1Tok, argument: null, data: {clientIdentity: {}}, expectedStatus: 400, expectedData: null, description: 'must not be able to upload a client identity in an invalid format'}),
  () => ({method: 'post', endpoint: 'client_identity', token: user1Tok, argument: null, data: {clientIdentity: user1_id1}, expectedStatus: 200, expectedData: null, description: 'upload a client identity for user1'}),
  () => ({method: 'post', endpoint: 'client_identity', token: user1Tok, argument: null, data: {clientIdentity: user1_id1}, expectedStatus: 409, expectedData: null, description: 'must not be able upload a client identity with already existing id'}),
  () => ({method: 'delete', endpoint: 'session', token: user1Tok, argument: null, data: null, expectedStatus: 200, expectedData: null, description: 'logout user1'}),
  () => ({method: 'post', endpoint: 'client_identity', token: user1Tok, argument: null, data: {clientIdentity: user1_id2}, expectedStatus: 403, expectedData: null, description: 'must not be able upload a client identity using an expired session token'}),
  {method: 'post', endpoint: 'user_account', token: null, argument: null, data: {login: 'user2', password1: '123456789', password2: '123456789'}, expectedStatus: 200, expectedData: null, description: 'register user2'},
  {method: 'post', endpoint: 'session', token: null, argument: null, data: {login: 'user2', password: '987654321'}, expectedStatus: 403, expectedData: null, description: 'user 2 login with wrong password'},
  {method: 'post', endpoint: 'session', token: null, argument: null, data: {login: 'user2', password: '123456789'}, expectedStatus: 200, expectedData: null, description: 'ok login', callback: data => user2Tok = data.token},
  () => ({method: 'post', endpoint: 'client_identity', token: user2Tok, argument: null, data: {clientIdentity: user2_id1}, expectedStatus: 200, expectedData: null, description: 'upload a client identity for user2 (same server as user1)'}),
  {method: 'post', endpoint: 'session', token: null, argument: null, data: {login: 'user1', password: 'abcdefgh'}, expectedStatus: 200, expectedData: null, description: 'login user1 again', callback: data => user1Tok = data.token},
  () => ({method: 'post', endpoint: 'client_identity', token: user1Tok, argument: null, data: {clientIdentity: user1_id2}, expectedStatus: 200, expectedData: null, description: 'upload another client identity for user1'}),
  () => ({method: 'get', endpoint: 'client_identity', token: user1Tok, argument: user1_id1.server.id, data: null, expectedStatus: 200, expectedData: {clientIdentity: user1_id1}, description: 'download a client identity for user1'}),
  () => ({method: 'get', endpoint: 'client_identity', token: user2Tok, argument: user2_id1.server.id, data: null, expectedStatus: 200, expectedData: {clientIdentity: user2_id1}, description: 'download a client identity for user2'}),
  () => ({method: 'get', endpoint: 'client_identity', token: user1Tok, argument: null, data: null, expectedStatus: 200, expectedData: {clientIdentities: [user1_id1, user1_id2]}, description: 'download all the client identities for user1'})
];

tap.plan(testRequests.length);

const validate = (schemaName, data, description) => {
  console.log('Validating ' + JSON.stringify(data) + ' against ' + schemaName);
  tap.ok(ajv.validate(schemaName, data), 'validate JSON of "' + description + '"');
};

const nextTest = (i) => {
  if (i >= testRequests.length)
    return;
  const testData = typeof testRequests[i] === 'function' ? testRequests[i]() : testRequests[i];
  const path = '/api/' + testData.endpoint + (testData.argument === null ? '' : '/' + testData.argument);
  console.log('Request: ' + testData.method.toUpperCase() + ' ' + path);
  let req = request(app);
  switch(testData.method) {
    case 'get': req = req.get(path); break;
    case 'post': req = req.post(path); break;
    case 'delete': req = req.delete(path); break;
    default: throw 'Unsupported method';
  }
  if(testData.token !== null)
    req = req.set('Session-Token', testData.token);
  if(testData.data !== null)
    req = req.send(testData.data);
  req.expect(testData.expectedStatus);
  if(testData.expectedData !== null)
    req.expect(testData.expectedData);
  req.end((err, res) => {
    if(err)
      tap.fail('Test "' + testData.description + '" failed with: ' + err.message);
    else if (res.status !== 200)
      validate('_responseError', res.body, testData.description);
    else {
      const baseSchemaName = 'response_' + testData.method + '_' + testData.endpoint;
      const argumentSpecificSchemaName = baseSchemaName + (testData.argument === null ? '_0' : '_1');
      if(schemaList.indexOf(baseSchemaName) > -1)
        validate(baseSchemaName, res.body, testData.description);
      else if (schemaList.indexOf(argumentSpecificSchemaName) > -1)
        validate(argumentSpecificSchemaName, res.body, testData.description);
      else {
        console.log('Asserting response body is empty');
        tap.deepEqual(res.body, {});
      }
    }
    if (testData.callback !== undefined)
      testData.callback(res.body);
    nextTest(i + 1);
  });
};
nextTest(0);
