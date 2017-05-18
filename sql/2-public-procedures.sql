-- stored procedures intended to be called by the app user

-- user_account
CREATE FUNCTION post_user_account(body JSON) RETURNS VOID AS $$
  BEGIN
    IF (body->>'password1') <> (body->>'password2') THEN
      PERFORM raiseCustomException(400, 'Entered passwords do not match');
    END IF;
    IF length(body->>'password1') < 8 THEN
      PERFORM raiseCustomException(400, 'The password must be at least 8 characters long.');
    END IF;
    INSERT INTO user_account (login, password) VALUES (body->>'login', crypt(body->>'password1', gen_salt('bf', 8)));
  EXCEPTION
      WHEN unique_violation THEN PERFORM raiseCustomException(409, 'The specified username is not available.');
      WHEN check_violation OR string_data_right_truncation THEN
        PERFORM raiseCustomException(400, 'The username must be at least 4 and at most 40 characters long, and must contain alphanumeric characters and underscores only.');
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- session
CREATE FUNCTION post_session(body JSON) RETURNS JSON AS $$
  DECLARE
    userID INT;
    s_token UUID;
  BEGIN
    SELECT id INTO userID FROM user_account U WHERE U.login = (body->>'login') AND (U.password = crypt(body->>'password', U.password));
    IF NOT FOUND THEN
      PERFORM raiseCustomException(403, 'Invalid login or password');
    END IF;
    INSERT INTO session(user_account_id) VALUES (userID) RETURNING token INTO s_token;
    RETURN json_build_object('token', s_token);
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION get_session(body JSON, urlArgument TEXT) RETURNS JSON AS $$
  DECLARE
    userID INT;
  BEGIN
    userID := auth(urlArgument::UUID);
    RETURN json_build_object('login', login) FROM user_account WHERE id = userID;
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION delete_session(body JSON, urlArgument TEXT) RETURNS VOID AS $$
  BEGIN
    PERFORM auth(urlArgument::UUID); --ensure session exists (transaction will be cancelled if auth() fails)
    DELETE FROM session WHERE token = urlArgument::UUID;
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- client_identity
CREATE FUNCTION get_client_identity(body JSON) RETURNS JSON AS $$
  DECLARE
    userID INT;
  BEGIN
    userID := auth((body->>'sessionToken')::UUID);
    RETURN json_build_object('clientIdentities', COALESCE(json_agg(json_identity(CL_ID, CL_CRT, SRV_CRT)), '[]'))
      FROM client_identity CL_ID
        JOIN public_cert CL_CRT ON CL_ID.public_cert_id = CL_CRT.internal_id
        JOIN public_cert SRV_CRT ON CL_ID.server_public_cert_id = SRV_CRT.internal_id
      WHERE CL_ID.user_account_id = userID;
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION get_client_identity(body JSON, urlArgument TEXT) RETURNS JSON AS $$
  DECLARE
    userID INT;
  BEGIN
    userID := auth((body->>'sessionToken')::UUID);
    RETURN json_build_object('clientIdentity', json_identity(CL_ID, CL_CRT, SRV_CRT))
      FROM client_identity CL_ID
        JOIN public_cert CL_CRT ON CL_ID.public_cert_id = CL_CRT.internal_id
        JOIN public_cert SRV_CRT ON CL_ID.server_public_cert_id = SRV_CRT.internal_id
      WHERE CL_ID.user_account_id = userID AND SRV_CRT.id = urlArgument::UUID;
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION post_client_identity(body JSON) RETURNS VOID AS $$
  DECLARE
    userID INT;
    clientIdentity JSON;
    serverCertId INT;
    clientCertId INT;
    privateModulus BYTEA;
    privateExponent BYTEA;
  BEGIN
    userID := auth((body->>'sessionToken')::UUID);
    clientIdentity := body->'clientIdentity';
    privateModulus := decode((clientIdentity->'clientPrivate')->>'modulus', 'base64');
    privateExponent := decode((clientIdentity->'clientPrivate')->>'exponent', 'base64');
    clientCertId := insert_public_cert(clientIdentity->'clientPublic');
    SELECT internal_id INTO serverCertId FROM public_cert WHERE id = ((clientIdentity->'server')->>'id')::UUID;
    IF NOT FOUND THEN
      serverCertId := insert_public_cert(clientIdentity->'server');
    END IF;
    INSERT INTO client_identity(user_account_id, public_cert_id, server_public_cert_id, private_cert_modulus, private_cert_exponent)
      VALUES (userID, clientCertID, serverCertId, privateModulus, privateExponent);
    EXCEPTION
      WHEN unique_violation THEN PERFORM raiseCustomException(409, 'A client identity certificate with the same ID already exists.');
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
