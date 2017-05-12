BEGIN;
SET search_path TO terasologykeys, public;
SELECT plan(1);
INSERT INTO user_account(id, login, password) VALUES (1, 'testUsername', 'testPassword');
INSERT INTO session(user_account_id, token) VALUES(1, '82359f4e-0ea7-4f96-b79f-0f175d2072ab');
SELECT is(auth('82359f4e-0ea7-4f96-b79f-0f175d2072ab'), 1);
SELECT finish();
ROLLBACK;
