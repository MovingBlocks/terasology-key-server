-- stored procedures not accessible to the app user

CREATE FUNCTION auth(sessionToken UUID) RETURNS INT AS $$
  DECLARE
    userID INT;
  BEGIN
    SELECT user_account_id INTO userID FROM session WHERE token = sessionToken;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid session token';
    END IF;
    -- TODO: check if session has expired
    RETURN userID;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION json_public_cert(crt public_cert) RETURNS JSON AS $$
    SELECT json_build_object(
      'id', crt.id,
      'modulus', encode(crt.modulus, 'base64'),
      'exponent', encode(crt.exponent, 'base64'),
      'signature', encode(crt.signature, 'base64')
      ) AS result;
$$ LANGUAGE sql;

CREATE FUNCTION json_private_cert(modulus BYTEA, exponent BYTEA) RETURNS JSON AS $$
    SELECT json_build_object(
      'modulus', encode(modulus, 'base64'),
      'exponent', encode(exponent, 'base64')
      ) AS result;
$$ LANGUAGE sql;

CREATE FUNCTION json_identity(cl_id client_identity, cl_crt public_cert, srv_crt public_cert) RETURNS JSON AS $$
    SELECT json_build_object(
      'server', json_public_cert(srv_crt),
      'clientPublic', json_public_cert(cl_crt),
      'clientPrivate', json_private_cert(cl_id.private_cert_modulus, cl_id.private_cert_exponent)
      ) AS result;
$$ LANGUAGE sql;

CREATE FUNCTION insert_public_cert(cert JSON) RETURNS INT AS $$
  INSERT INTO public_cert(id, modulus, exponent, signature) VALUES(
    (cert->>'id')::UUID,
    decode(cert->>'modulus', 'base64'),
    decode(cert->>'exponent', 'base64'),
    decode(cert->>'signature', 'base64')
    ) RETURNING internal_id AS result;
$$ LANGUAGE sql;
