BEGIN;
SET search_path TO terasologykeys, public;
SELECT plan(1);

INSERT INTO user_account(id, login, password) VALUES (1, 'test', 'test');
INSERT INTO public_cert(internal_id, id, modulus, exponent, signature) VALUES (1,
  'd2c8637a-7416-47f5-badb-5b77dba50e68', '123'::BYTEA, '456'::BYTEA, '789'::BYTEA);
INSERT INTO public_cert(internal_id, id, modulus, exponent, signature) VALUES (2,
    'ce49c253-1065-4dc0-a11b-fc06f16379ef', 'abc'::BYTEA, 'def'::BYTEA, 'ghi'::BYTEA);
INSERT INTO client_identity(user_account_id, public_cert_id, server_public_cert_id,
  private_cert_modulus, private_cert_exponent) VALUES(1, 1, 2, 'prv1'::BYTEA, 'prv2'::BYTEA);

--JSON values are converted to JSONB since there is no comparison operator for plain JSON
-- (see: https://www.postgresql.org/docs/9.6/static/functions-json.html )

PREPARE jsonident AS
  SELECT json_identity(CLID, CLPUB, SRVPUB)::JSONB
  FROM client_identity CLID
    JOIN public_cert CLPUB ON CLID.public_cert_id = CLPUB.internal_id
    JOIN public_cert SRVPUB ON CLID.server_public_cert_id = SRVPUB.internal_id;

PREPARE expected AS SELECT '{
  "server": {"id": "ce49c253-1065-4dc0-a11b-fc06f16379ef", "modulus": "YWJj", "exponent": "ZGVm", "signature": "Z2hp"},
  "clientPublic": {"id": "d2c8637a-7416-47f5-badb-5b77dba50e68", "modulus": "MTIz", "exponent": "NDU2", "signature": "Nzg5"},
  "clientPrivate": {"modulus": "cHJ2MQ==", "exponent": "cHJ2Mg=="}}'::JSONB;

SELECT set_has('jsonident', 'expected');

SELECT finish();
ROLLBACK;
