--NOTE 6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe is a test key! Please replace the function before using in production.
--Info about the test keys here: https://developers.google.com/recaptcha/docs/faq#id-like-to-run-automated-tests-with-recaptcha-v2-what-should-i-do
CREATE SCHEMA config;
CREATE OR REPLACE FUNCTION config.get_reCAPTCHA_secret() RETURNS TEXT AS $$
  SELECT '6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe'::TEXT;
$$ LANGUAGE sql;

CREATE FUNCTION pg_temp.get_app_user_name() RETURNS TEXT AS $$
  SELECT 'terasologykeys_app'::TEXT;
$$ LANGUAGE sql;

CREATE FUNCTION pg_temp.get_app_user_password() RETURNS TEXT AS $$
  SELECT '11804923f96c2e4e5f336cb623ae15f63481f4acdb295727ecdc4adacf9b365a'::TEXT;
$$ LANGUAGE sql;

CREATE FUNCTION pg_temp.get_batch_user_name() RETURNS TEXT AS $$
  SELECT 'terasologykeys_batch'::TEXT;
$$ LANGUAGE sql;

CREATE FUNCTION pg_temp.get_batch_user_password() RETURNS TEXT AS $$
  SELECT 'ffafd66fd860bd7ad9d86c7e861799994b04aba4720233c4b8b55e630e777e1a'::TEXT;
$$ LANGUAGE sql;

CREATE FUNCTION pg_temp.get_backup_user_name() RETURNS TEXT AS $$
  SELECT 'terasologykeys_backup'::TEXT;
$$ LANGUAGE sql;

CREATE FUNCTION pg_temp.get_backup_user_password() RETURNS TEXT AS $$
  SELECT 'c20808829becd3f30e7ea4a11c31e6fef60cd678f3f33742796329176b22df70'::TEXT;
$$ LANGUAGE sql;
