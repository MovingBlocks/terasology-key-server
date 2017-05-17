-- generate the app user and assign privileges

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA terasologykeys FROM PUBLIC;

DO $$ BEGIN
  IF EXISTS (SELECT * FROM pg_catalog.pg_user WHERE usename = 'terasologykeys_app') THEN
    REVOKE ALL ON ALL FUNCTIONS IN SCHEMA terasologykeys FROM terasologykeys_app;
    REVOKE USAGE ON SCHEMA terasologykeys FROM terasologykeys_app;
    REVOKE CONNECT ON DATABASE terasologykeys FROM terasologykeys_app;
  END IF;
END; $$;

DROP ROLE IF EXISTS terasologykeys_app;
CREATE ROLE terasologykeys_app NOINHERIT LOGIN PASSWORD '11804923f96c2e4e5f336cb623ae15f63481f4acdb295727ecdc4adacf9b365a';
ALTER ROLE terasologykeys_app SET search_path=terasologykeys, public;
GRANT CONNECT ON DATABASE terasologykeys TO terasologykeys_app;
GRANT USAGE ON SCHEMA terasologykeys TO terasologykeys_app;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA terasologykeys FROM terasologykeys_app;

GRANT EXECUTE ON FUNCTION post_user_account(JSON) TO terasologykeys_app;
GRANT EXECUTE ON FUNCTION post_session(JSON) TO terasologykeys_app;
GRANT EXECUTE ON FUNCTION get_session(JSON, TEXT) TO terasologykeys_app;
GRANT EXECUTE ON FUNCTION delete_session(JSON, TEXT) TO terasologykeys_app;
GRANT EXECUTE ON FUNCTION get_client_identity(JSON) TO terasologykeys_app;
GRANT EXECUTE ON FUNCTION get_client_identity(JSON, TEXT) TO terasologykeys_app;
GRANT EXECUTE ON FUNCTION post_client_identity(JSON) TO terasologykeys_app;
