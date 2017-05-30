-- stored procedures not accessible to the app user

CREATE FUNCTION raiseCustomException(httpStatus INT, message TEXT) RETURNS VOID AS $$
  BEGIN
    RAISE EXCEPTION 'customError' USING DETAIL = json_build_object('status', httpStatus, 'message', message);
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION timestamp_valid(t TIMESTAMP, validity INTERVAL) RETURNS BOOLEAN AS $$
  SELECT CURRENT_TIMESTAMP - t < validity;
$$ LANGUAGE sql;

CREATE FUNCTION session_timestamp_valid(t TIMESTAMP) RETURNS BOOLEAN AS $$
  SELECT timestamp_valid(t, '24 hours'::INTERVAL)
$$ LANGUAGE sql;

CREATE FUNCTION account_verification_timestamp_valid(t TIMESTAMP) RETURNS BOOLEAN AS $$
  SELECT timestamp_valid(t, '2 hours'::INTERVAL)
$$ LANGUAGE sql;

CREATE FUNCTION cleanup_expired_tokens() RETURNS VOID AS $$
  DELETE FROM session WHERE NOT session_timestamp_valid(login_timestamp);
  DELETE FROM user_account WHERE confirmToken IS NOT NULL AND NOT requestedPasswordReset AND NOT account_verification_timestamp_valid(confirmTokenTimestamp);
$$ LANGUAGE sql SECURITY DEFINER;

CREATE FUNCTION auth(sessionToken UUID) RETURNS INT AS $$
  DECLARE
    userID INT;
  BEGIN
    SELECT user_account_id INTO userID FROM session
      WHERE token = sessionToken AND session_timestamp_valid(login_timestamp);
    IF NOT FOUND THEN
      PERFORM raiseCustomException(403, 'Invalid or expired session token');
    END IF;
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
