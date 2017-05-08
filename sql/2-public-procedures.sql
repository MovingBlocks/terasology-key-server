-- stored procedures intended to be called by the app user

-- user_account
CREATE FUNCTION post_user_account(body JSON) RETURNS VOID AS $$
  BEGIN
    IF (body->>'password1') <> (body->>'password2') THEN
      PERFORM raiseCustomException(400, 'Passwords do not match');
    END IF;
    INSERT INTO user_account (login, password) VALUES (body->>'login', body->>'password1');
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- session
CREATE FUNCTION post_session(body JSON) RETURNS JSON AS $$
  DECLARE
    userID INT;
    s_token UUID;
  BEGIN
    SELECT id INTO userID FROM user_account U WHERE U.login = (body->>'login') AND (U.password = body->>'password');
    IF NOT FOUND THEN
      PERFORM raiseCustomException(403, 'Invalid login or password');
    END IF;
    INSERT INTO session(user_account_id, login_timestamp) VALUES (userID, CURRENT_TIMESTAMP) RETURNING token INTO s_token;
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
    RETURN json_build_object('clientIdentities', json_agg(json_identity(CL_ID, CL_CRT, SRV_CRT)))
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
    serverCertId INT;
    clientCertId INT;
    privateModulus BYTEA;
    privateExponent BYTEA;
  BEGIN
    userID := auth((body->>'sessionToken')::UUID);
    privateModulus := decode((body->'clientPrivate')->>'modulus', 'base64');
    privateExponent := decode((body->'clientPrivate')->>'exponent', 'base64');
    clientCertId := insert_public_cert(body->'clientPublic');
    SELECT internal_id INTO serverCertId FROM public_cert WHERE id = ((body->'server')->>'id')::UUID;
    IF NOT FOUND THEN
      serverCertId := insert_public_cert(body->'server');
    END IF;
    INSERT INTO client_identity(user_account_id, public_cert_id, server_public_cert_id, private_cert_modulus, private_cert_exponent)
      VALUES (userID, clientCertID, serverCertId, privateModulus, privateExponent);
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
