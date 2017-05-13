BEGIN;
SET search_path TO terasologykeys, public;
SELECT plan(5);

-- get (list)
INSERT INTO user_account(id, login, password) VALUES (1, 'testUser', 'testPass');
-- identity of the user on a server
INSERT INTO public_cert(internal_id, id, modulus, exponent, signature) VALUES (1,
  'd2c8637a-7416-47f5-badb-5b77dba50e68', '123'::BYTEA, '456'::BYTEA, '789'::BYTEA);
INSERT INTO public_cert(internal_id, id, modulus, exponent, signature) VALUES (2,
  'ce49c253-1065-4dc0-a11b-fc06f16379ef', 'abc'::BYTEA, 'def'::BYTEA, 'ghi'::BYTEA);
INSERT INTO client_identity(user_account_id, public_cert_id, server_public_cert_id,
  private_cert_modulus, private_cert_exponent) VALUES (1, 1, 2, 'prv1'::BYTEA, 'prv2'::BYTEA);
--identity on another server
INSERT INTO public_cert(internal_id, id, modulus, exponent, signature) VALUES (3,
  '9d355883-ee55-435e-8f0f-13829e83958d', 'aaa'::BYTEA, 'bbb'::BYTEA, 'ccc'::BYTEA);
INSERT INTO public_cert(internal_id, id, modulus, exponent, signature) VALUES (4,
  '74c2c0c4-851c-4e95-9690-13e1fb3c0eac', '333'::BYTEA, '222'::BYTEA, '111'::BYTEA);
INSERT INTO client_identity(user_account_id, public_cert_id, server_public_cert_id,
  private_cert_modulus, private_cert_exponent) VALUES (1, 3, 4, 'prv3'::BYTEA, 'prv4'::BYTEA);

INSERT INTO session(token, user_account_id) VALUES ('a236721c-ed37-4097-9d45-e6989463a203', 1);
PREPARE bad_login AS SELECT get_client_identity('{"sessionToken": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}'::JSON);
SELECT throws_ok('bad_login', 'customError');
PREPARE ok_login AS SELECT get_client_identity('{"sessionToken": "a236721c-ed37-4097-9d45-e6989463a203"}'::JSON)::JSONB;
PREPARE expected AS SELECT '{
  "clientIdentities": [
    {
      "server": {
        "id": "ce49c253-1065-4dc0-a11b-fc06f16379ef",
        "modulus": "YWJj",
        "exponent": "ZGVm",
        "signature": "Z2hp"
      },
      "clientPublic": {
        "id": "d2c8637a-7416-47f5-badb-5b77dba50e68",
        "modulus": "MTIz",
        "exponent": "NDU2",
        "signature": "Nzg5"
      },
      "clientPrivate": {
        "modulus": "cHJ2MQ==",
        "exponent": "cHJ2Mg=="
      }
    }, {
      "server": {
        "id": "74c2c0c4-851c-4e95-9690-13e1fb3c0eac",
        "modulus": "MzMz",
        "exponent": "MjIy",
        "signature": "MTEx"
      },
      "clientPublic": {
        "id": "9d355883-ee55-435e-8f0f-13829e83958d",
        "modulus": "YWFh",
        "exponent": "YmJi",
        "signature": "Y2Nj"
      },
      "clientPrivate": {
        "modulus": "cHJ2Mw==",
        "exponent": "cHJ2NA=="
      }
    }
  ]
}'::JSONB;
SELECT results_eq('ok_login', 'expected');
DEALLOCATE ALL;

-- get (single)
INSERT INTO user_account(id, login, password) VALUES (2, 'testUser2', 'testPass2');
INSERT INTO public_cert(internal_id, id, modulus, exponent, signature) VALUES (5,
  'b7ac1fae-896e-4968-873c-01ced22652be', '4'::BYTEA, '5'::BYTEA, '6'::BYTEA);
INSERT INTO public_cert(internal_id, id, modulus, exponent, signature) VALUES (6,
  '2953279c-71e2-46f8-a10f-802ec535bed8', 'ddd'::BYTEA, 'eee'::BYTEA, 'fff'::BYTEA);
INSERT INTO client_identity(user_account_id, public_cert_id, server_public_cert_id,
  private_cert_modulus, private_cert_exponent) VALUES (2, 5, 6, 'prv5'::BYTEA, 'prv6'::BYTEA);
INSERT INTO session(token, user_account_id) VALUES ('c5488c11-d047-4844-b57e-126670af6db0', 2);
PREPARE bad_login AS SELECT get_client_identity('{"sessionToken": "00000000-0000-0000-0000-000000000000"}'::JSON,
  '2953279c-71e2-46f8-a10f-802ec535bed8')::JSONB;
SELECT throws_ok('bad_login', 'customError');
PREPARE ok_login AS SELECT get_client_identity('{"sessionToken": "c5488c11-d047-4844-b57e-126670af6db0"}'::JSON,
  '2953279c-71e2-46f8-a10f-802ec535bed8')::JSONB;
PREPARE expected AS SELECT '{"clientIdentity": {
  "server": {
    "id": "2953279c-71e2-46f8-a10f-802ec535bed8",
    "modulus": "ZGRk",
    "exponent": "ZWVl",
    "signature": "ZmZm"
  },
  "clientPublic": {
    "id": "b7ac1fae-896e-4968-873c-01ced22652be",
    "modulus": "NA==",
    "exponent": "NQ==",
    "signature": "Ng=="
  },
  "clientPrivate": {
    "modulus": "cHJ2NQ==",
    "exponent": "cHJ2Ng=="
  }
}}'::JSONB;
SELECT results_eq('ok_login', 'expected');
DEALLOCATE ALL;
SELECT setval('public_cert_internal_id_seq', (SELECT MAX(internal_id) FROM public_cert)); --sync sequence

-- post
INSERT INTO user_account(id, login, password) VALUES (3, 'yetAnotherUser', 'yetAnotherPass');
INSERT INTO session(token, user_account_id) VALUES ('e306a4f8-b178-4e27-9476-f8c8f57f07dc', 3);
SELECT post_client_identity('{
  "sessionToken": "e306a4f8-b178-4e27-9476-f8c8f57f07dc",
  "server": {
    "id": "55833d5b-1671-4a5d-a4cd-58dcc04e3235",
    "modulus": "cHFy",
    "exponent": "c3R1",
    "signature": "dnd4"
  },
  "clientPublic": {
    "id": "51409c50-7ba2-4021-b175-f47e28d1fd58",
    "modulus": "Z2hp",
    "exponent": "amts",
    "signature": "bW5v"
  },
  "clientPrivate": {
    "modulus": "YWJj",
    "exponent": "ZGVm"
  }
}');
PREPARE inserted_ident AS SELECT CL_ID.private_cert_modulus AS prvMod, CL_ID.private_cert_exponent AS prvExp,
  CL_CRT.id AS pubId, CL_CRT.modulus AS pubMod, CL_CRT.exponent AS pubExp, CL_CRT.signature AS pubSgn,
  SRV_CRT.id AS svrId, SRV_CRT.modulus AS srvMod, SRV_CRT.exponent AS srvExp, SRV_CRT.signature AS srvSgn
  FROM client_identity CL_ID
  JOIN public_cert CL_CRT ON CL_ID.public_cert_id = CL_CRT.internal_id
  JOIN public_cert SRV_CRT ON CL_ID.server_public_cert_id = SRV_CRT.internal_id
  WHERE CL_ID.user_account_id = 3;
PREPARE expected AS SELECT 'abc'::BYTEA AS prvMod, 'def'::BYTEA AS prvExp,
  '51409c50-7ba2-4021-b175-f47e28d1fd58'::UUID AS pubId, 'ghi'::BYTEA AS pubMod, 'jkl'::BYTEA AS pubExp, 'mno'::BYTEA AS pubSgn,
  '55833d5b-1671-4a5d-a4cd-58dcc04e3235'::UUID AS svrId, 'pqr'::BYTEA AS srvMod, 'stu'::BYTEA AS srvExp, 'vwx'::BYTEA AS srvSgn
  FROM client_identity CL_ID;
SELECT set_has('inserted_ident', 'expected');

SELECT finish();
ROLLBACK;
