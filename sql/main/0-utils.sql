-- from https://dba.stackexchange.com/a/122777

CREATE OR REPLACE FUNCTION pg_temp.drop_all_functions_in_schema(_sch text)
  RETURNS void AS
$func$
DECLARE
   _sql text;
BEGIN
   SELECT INTO _sql
          string_agg(format('DROP FUNCTION %s(%s);'
                          , p.oid::regproc
                          , pg_get_function_identity_arguments(p.oid))
                   , E'\n')
   FROM   pg_proc      p
   JOIN   pg_namespace ns ON ns.oid = p.pronamespace
   WHERE  ns.nspname = _sch;

   IF _sql IS NOT NULL THEN
      --  RAISE NOTICE '%', _sql;  -- for debugging
      EXECUTE _sql;
   END IF;
END
$func$ LANGUAGE plpgsql;
