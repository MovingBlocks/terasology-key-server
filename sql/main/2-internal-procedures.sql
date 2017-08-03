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

CREATE FUNCTION assertUrl(actual TEXT, expected TEXT) RETURNS VOID AS $$
  BEGIN
    IF actual <> expected THEN
      PERFORM raiseCustomException(404, 'Not Found');
    END IF;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION validatePassword(password1 TEXT, password2 TEXT) RETURNS VOID AS $$
  BEGIN
    IF password1 <> password2 THEN
      PERFORM raiseCustomException(400, 'Entered passwords do not match');
    END IF;
    IF length(password1) < 8 THEN
      PERFORM raiseCustomException(400, 'The password must be at least 8 characters long.');
    END IF;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION checkRecaptcha(answer TEXT) RETURNS VOID AS $$
  DECLARE
    response JSON;
  BEGIN
    IF answer IS NULL THEN
     --for the unit and integration tests
      answer = '03AOPBWq_WzyjPeyh1aNzhFpH2dEapEuN00Jy0PqJGipjrvW2RFD6cWBCfx7GOmKkQd-heVB3VVYusZtJbF1glB3Q-nzs1h95SuU8GT5Fqq_cL9y9U2NEq53h1wXBDNtYDikJ6xjuzicAkgqfSBTON-ec5BH5nfVxWiUqhl6irQB9bmMe3dH48L7Pnx1vqb5-PL_dKEB-ICzf-8v2kIiBIJlwUVurAkClqrup8wLDVBBV_FGu0mO-D0k1Gx39NH5zGAyANqbAg1wjaZeDZQ5t-tKBJzCZW0AK-x7SilcUcQBSzJwb6p40XGJY';
    END IF;
    SELECT content::JSON INTO response FROM public.http_post(
      'https://www.google.com/recaptcha/api/siteverify',
      'secret=' || get_reCAPTCHA_secret() || '&response=' || answer,
      'application/x-www-form-urlencoded');
    IF NOT (response->>'success')::BOOLEAN THEN
      RAISE NOTICE 'reCAPTCHA validation failure: %', (response->>'error-codes')::TEXT;
      PERFORM raiseCustomException(403, 'reCAPTCHA validation failed.');
    END IF;
  END;
$$ LANGUAGE plpgsql;
