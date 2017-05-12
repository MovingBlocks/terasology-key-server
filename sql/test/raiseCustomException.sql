BEGIN;
SET search_path TO terasologykeys, public;
SELECT plan(1);
PREPARE exceptionTest AS SELECT raiseCustomException(404, 'testError');
SELECT throws_ok('exceptionTest', 'customError');
SELECT finish();
ROLLBACK;
