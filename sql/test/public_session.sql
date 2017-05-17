BEGIN;
SET search_path TO terasologykeys, public;
SELECT plan(4);

-- post
INSERT INTO user_account(id, login, password) VALUES (1, 'testUser', crypt('testPass', gen_salt('bf', 8)));
PREPARE bad_login AS SELECT post_session('{"login": "testUser", "password": "wrong"}'::JSON);
SELECT throws_ok('bad_login', 'customError');
PREPARE ok_login_tok AS SELECT (post_session(
  '{"login": "testUser", "password": "testPass"}'::JSON)->>'token')::UUID;
PREPARE tok_in_table AS SELECT token FROM session JOIN user_account ON user_account_id=id
      WHERE login='testUser' AND password=crypt('testPass', password);
SELECT results_eq('ok_login_tok', 'tok_in_table');

-- get
INSERT INTO user_account(id, login, password) VALUES (2, 'anotherUser', 'anotherPass');
INSERT INTO session(token, user_account_id) VALUES ('42d05511-8786-404a-8bfe-f0f74975b985', 2);
PREPARE get_result AS SELECT (get_session(NULL, '42d05511-8786-404a-8bfe-f0f74975b985'))->>'login';
SELECT results_eq('get_result', ARRAY['anotherUser']);

-- delete
INSERT INTO user_account(id, login, password) VALUES (3, 'yetAnotherUser', 'yetAnotherPass');
INSERT INTO session(token, user_account_id) VALUES ('bc32a32f-e977-4351-90ee-1a470135917d', 3);
SELECT delete_session(NULL, 'bc32a32f-e977-4351-90ee-1a470135917d');
SELECT is_empty('SELECT * FROM session WHERE user_account_id=3');

SELECT finish();
ROLLBACK;
