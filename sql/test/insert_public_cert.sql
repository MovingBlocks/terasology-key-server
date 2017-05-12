BEGIN;
SET search_path TO terasologykeys, public;
SELECT plan(1);
SELECT insert_public_cert('{"id": "d2c8637a-7416-47f5-badb-5b77dba50e68",
  "modulus": "YWJjZA==", "exponent": "ZWZn", "signature": "aGk="}'::JSON);
PREPARE expected AS (SELECT 'd2c8637a-7416-47f5-badb-5b77dba50e68'::UUID AS id,
  'abcd'::BYTEA AS modulus, 'efg'::BYTEA AS exponent, 'hi'::BYTEA AS signature);
SELECT set_has('SELECT id, modulus, exponent, signature FROM public_cert', 'expected');
SELECT finish();
ROLLBACK;
