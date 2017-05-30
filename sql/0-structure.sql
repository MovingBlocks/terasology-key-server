-- database structure

DROP SCHEMA IF EXISTS terasologykeys CASCADE;
CREATE SCHEMA terasologykeys;

SET search_path TO 'terasologykeys';

CREATE TABLE user_account(
  id SERIAL PRIMARY KEY,
  login VARCHAR(40) NOT NULL UNIQUE,
  password TEXT NOT NULL,
  CHECK(login ~ '^[A-Za-z0-9_]{4,40}$')
);

CREATE TABLE session (
  token UUID PRIMARY KEY DEFAULT public.uuid_generate_v4(),
  user_account_id INT NOT NULL REFERENCES user_account(id) ON UPDATE CASCADE ON DELETE NO ACTION,
  login_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public_cert (
  internal_id SERIAL PRIMARY KEY,
  id UUID UNIQUE,
  modulus BYTEA NOT NULL,
  exponent BYTEA NOT NULL,
  signature BYTEA NOT NULL
);

CREATE TABLE client_identity (
  user_account_id INT NOT NULL REFERENCES user_account(id),
  public_cert_id INT PRIMARY KEY REFERENCES public_cert(internal_id) ON UPDATE CASCADE ON DELETE NO ACTION,
  server_public_cert_id INT NOT NULL REFERENCES public_cert(internal_id) ON UPDATE CASCADE ON DELETE NO ACTION,
  private_cert_modulus BYTEA NOT NULL,
  private_cert_exponent BYTEA NOT NULL,
  UNIQUE(user_account_id, server_public_cert_id)
);
