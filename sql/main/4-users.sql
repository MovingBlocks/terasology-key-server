REVOKE ALL ON ALL FUNCTIONS IN SCHEMA terasologykeys FROM PUBLIC;

CREATE FUNCTION pg_temp.create_restricted_user(role_name TEXT, pswd TEXT) RETURNS VOID AS $$
  BEGIN
    IF EXISTS (SELECT * FROM pg_catalog.pg_user WHERE usename = role_name) THEN
      EXECUTE 'REVOKE ALL ON ALL FUNCTIONS IN SCHEMA terasologykeys FROM ' || role_name ;
      EXECUTE 'REVOKE USAGE ON SCHEMA terasologykeys FROM ' || role_name;
      EXECUTE 'REVOKE CONNECT ON DATABASE terasologykeys FROM ' || role_name;
      EXECUTE 'DROP ROLE ' || role_name;
    END IF;
    EXECUTE 'CREATE ROLE ' || role_name || ' NOINHERIT LOGIN PASSWORD ''' || pswd || '''';
    EXECUTE 'ALTER ROLE ' || role_name || ' SET search_path=terasologykeys, public';
    EXECUTE 'GRANT CONNECT ON DATABASE terasologykeys TO ' || role_name;
    EXECUTE 'GRANT USAGE ON SCHEMA terasologykeys TO ' || role_name;
    EXECUTE 'REVOKE ALL ON ALL FUNCTIONS IN SCHEMA terasologykeys FROM ' || role_name;
    EXECUTE 'REVOKE ALL ON ALL TABLES IN SCHEMA terasologykeys FROM ' || role_name;
    EXECUTE 'REVOKE ALL ON ALL TABLES IN SCHEMA public FROM ' || role_name;
  END;
$$ LANGUAGE plpgsql;

DO $$
  BEGIN
    -- generate the app user
    PERFORM pg_temp.create_restricted_user(pg_temp.get_app_user_name(), pg_temp.get_app_user_password());
    EXECUTE 'GRANT EXECUTE ON FUNCTION post_user_account(JSON) TO ' || pg_temp.get_app_user_name();
    EXECUTE 'GRANT EXECUTE ON FUNCTION patch_user_account(JSON) TO ' || pg_temp.get_app_user_name();
    EXECUTE 'GRANT EXECUTE ON FUNCTION post_user_account(JSON, TEXT) TO ' || pg_temp.get_app_user_name();
    EXECUTE 'GRANT EXECUTE ON FUNCTION delete_user_account(JSON, TEXT) TO ' || pg_temp.get_app_user_name();
    EXECUTE 'GRANT EXECUTE ON FUNCTION post_session(JSON) TO ' || pg_temp.get_app_user_name();
    EXECUTE 'GRANT EXECUTE ON FUNCTION get_session(JSON, UUID) TO ' || pg_temp.get_app_user_name();
    EXECUTE 'GRANT EXECUTE ON FUNCTION delete_session(JSON, UUID) TO ' || pg_temp.get_app_user_name();
    EXECUTE 'GRANT EXECUTE ON FUNCTION get_client_identity(JSON, UUID) TO ' || pg_temp.get_app_user_name();
    EXECUTE 'GRANT EXECUTE ON FUNCTION get_client_identity(JSON, TEXT, UUID) TO ' || pg_temp.get_app_user_name();
    EXECUTE 'GRANT EXECUTE ON FUNCTION post_client_identity(JSON, UUID) TO ' || pg_temp.get_app_user_name();

    -- generate the batch user (for use by cron job to remove expired tokens)
    PERFORM pg_temp.create_restricted_user(pg_temp.get_batch_user_name(), pg_temp.get_batch_user_password());
    EXECUTE 'GRANT EXECUTE ON FUNCTION cleanup_expired_tokens() TO ' || pg_temp.get_batch_user_name();

    -- generate the backup user (read-only access to all tables)
    PERFORM pg_temp.create_restricted_user(pg_temp.get_backup_user_name(), pg_temp.get_backup_user_password());
    EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA terasologykeys TO ' || pg_temp.get_backup_user_name(); 
    EXECUTE 'GRANT SELECT ON ALL SEQUENCES IN SCHEMA terasologykeys TO ' || pg_temp.get_backup_user_name(); 

    RAISE NOTICE 'Finished installing schema and functions.';
  END;
$$;
