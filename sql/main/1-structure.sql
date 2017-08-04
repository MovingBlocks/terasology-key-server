-- database structure

CREATE SCHEMA IF NOT EXISTS terasologykeys;

SET search_path TO 'terasologykeys';

CREATE TABLE IF NOT EXISTS user_account(
  id SERIAL PRIMARY KEY,
  login VARCHAR(40) NOT NULL UNIQUE,
  password TEXT NOT NULL,
  email TEXT,
  confirmToken UUID UNIQUE,
  requestedPasswordReset BOOLEAN NOT NULL DEFAULT FALSE,
  confirmTokenTimestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, --can be the timestamp of the registration, or of the latest password reset request
  CHECK(login ~ '^[A-Za-z0-9_]{4,40}$'),
  CHECK(email IS NULL OR email ~ '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')
);

CREATE TABLE IF NOT EXISTS session (
  token UUID PRIMARY KEY DEFAULT public.gen_random_uuid(),
  user_account_id INT NOT NULL REFERENCES user_account(id) ON UPDATE CASCADE ON DELETE NO ACTION,
  login_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public_cert (
  internal_id SERIAL PRIMARY KEY,
  id UUID UNIQUE,
  modulus BYTEA NOT NULL,
  exponent BYTEA NOT NULL,
  signature BYTEA NOT NULL
);

CREATE TABLE IF NOT EXISTS client_identity (
  user_account_id INT NOT NULL REFERENCES user_account(id),
  public_cert_id INT PRIMARY KEY REFERENCES public_cert(internal_id) ON UPDATE CASCADE ON DELETE NO ACTION,
  server_public_cert_id INT NOT NULL REFERENCES public_cert(internal_id) ON UPDATE CASCADE ON DELETE NO ACTION,
  private_cert_modulus BYTEA NOT NULL,
  private_cert_exponent BYTEA NOT NULL,
  UNIQUE(user_account_id, server_public_cert_id)
);

SELECT pg_temp.drop_all_functions_in_schema('terasologykeys');
