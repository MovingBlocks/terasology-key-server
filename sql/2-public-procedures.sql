-- stored procedures intended to be called by the app user

-- user_account
CREATE FUNCTION post_user_account(body JSON) RETURNS VOID AS $$
  DECLARE
    confTok UUID;
    email TEXT;
  BEGIN
    PERFORM validatePassword(body->>'password1', body->>'password2');
    IF (body->>'email') IS NOT NULL AND (body->>'email') <> '' THEN
      email = body->>'email';
      confTok := public.uuid_generate_v4();
    END IF;
    INSERT INTO user_account (login, password, email, confirmToken) VALUES (body->>'login', crypt(body->>'password1', gen_salt('bf', 8)), email, confTok);
    IF email IS NOT NULL THEN
      PERFORM public.pgmail('Terasology Identity Storage Service <noreply@localhost>', 'User <'||(body->>'email')||'>', 'Confirm account registration',
        'Thank you for registering on this Terasology identity storage server!' || E'\n\n' ||
        'The code to verify your account is: ' || confTok || E'\n\n' ||
        'Paste this in the web page you used for registration to activate your account.' || E'\n' ||
        'NOTE: if an account is not verified in 2 hours after the registration form submission, it is deleted.');
    END IF;
  EXCEPTION
      WHEN unique_violation THEN PERFORM raiseCustomException(409, 'The specified username is not available.');
      WHEN check_violation OR string_data_right_truncation THEN
        PERFORM raiseCustomException(400, 'The username must be at least 4 and at most 40 characters long, and must contain alphanumeric characters and underscores only. If present, the email must be a valid email address.');
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION patch_user_account(body JSON) RETURNS VOID AS $$
  BEGIN
    UPDATE user_account SET confirmToken = NULL WHERE confirmToken = (body->>'confirmToken')::UUID
      AND NOT requestedPasswordReset AND account_verification_timestamp_valid(confirmTokenTimestamp);
    IF NOT FOUND THEN
      PERFORM raiseCustomException(403, 'The specified confirmation token is not valid or has expired.');
    END IF;
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- user_account/passwordReset
CREATE FUNCTION post_user_account(body JSON, urlArgument TEXT) RETURNS VOID AS $$
  DECLARE
    token UUID;
  BEGIN
    PERFORM assertUrl(urlArgument, 'passwordReset');
    token := public.uuid_generate_v4();
    UPDATE user_account SET confirmToken = token, confirmTokenTimestamp = CURRENT_TIMESTAMP, requestedPasswordReset = TRUE
      WHERE email = (body->>'email') AND login = (body->>'login') AND confirmToken IS NULL AND NOT requestedPasswordReset;
    IF NOT FOUND THEN
      PERFORM raiseCustomException(403, 'The specified account does not exists, has not been activated or already requested a password reset.');
    END IF;
    PERFORM public.pgmail('Terasology Identity Storage Service <noreply@localhost>', 'User <'||(body->>'email')||'>', 'Reset your password',
      'You requested to reset your account''s password on this Terasology identity storage server.' || E'\n\n' ||
      'The code to reset your password is: ' || token || E'\n\n' ||
      'Paste this in the web page you used to request the password reset to actually change your password.' || E'\n' ||
      'NOTE: if the password reset is not completed in 2 hours after the request form submission, the code is invalidated and you have to request a new one.');
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION delete_user_account(body JSON, urlArgument TEXT) RETURNS VOID AS $$
  BEGIN
    PERFORM assertUrl(urlArgument, 'passwordReset');
    PERFORM validatePassword(body->>'password1', body->>'password2');
    UPDATE user_account SET password = crypt(body->>'password1', gen_salt('bf', 8)), confirmToken = NULL, requestedPasswordReset = FALSE
      WHERE confirmToken = (body->>'confirmToken')::UUID AND requestedPasswordReset AND account_verification_timestamp_valid(confirmTokenTimestamp);
    IF NOT FOUND THEN
      PERFORM raiseCustomException(403, 'The specified password reset token is not valid or has expired.');
    END IF;
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- session
CREATE FUNCTION post_session(body JSON) RETURNS JSON AS $$
  DECLARE
    userID INT;
    enabled BOOLEAN;
    s_token UUID;
  BEGIN
    SELECT U.id, (U.confirmToken IS NULL AND NOT U.requestedPasswordReset) INTO userID, enabled
      FROM user_account U WHERE U.login = (body->>'login') AND (U.password = crypt(body->>'password', U.password));
    IF NOT FOUND THEN
      PERFORM raiseCustomException(403, 'Invalid login or password');
    ELSIF NOT enabled THEN
      PERFORM raiseCustomException(403, 'This account is not enabled. Check your email to get the token to activate the account.');
    END IF;
    INSERT INTO session(user_account_id) VALUES (userID) RETURNING token INTO s_token;
    RETURN json_build_object('token', s_token);
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION get_session(body JSON, sessionToken UUID) RETURNS JSON AS $$
  DECLARE
    userID INT;
  BEGIN
    userID := auth(sessionToken);
    RETURN json_build_object('login', login) FROM user_account WHERE id = userID;
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION delete_session(body JSON, sessionToken UUID) RETURNS VOID AS $$
  BEGIN
    PERFORM auth(sessionToken); --ensure session exists (transaction will be cancelled if auth() fails)
    DELETE FROM session WHERE token = sessionToken;
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- client_identity
CREATE FUNCTION get_client_identity(body JSON, sessionToken UUID) RETURNS JSON AS $$
  DECLARE
    userID INT;
  BEGIN
    userID := auth(sessionToken);
    RETURN json_build_object('clientIdentities', COALESCE(json_agg(json_identity(CL_ID, CL_CRT, SRV_CRT)), '[]'))
      FROM client_identity CL_ID
        JOIN public_cert CL_CRT ON CL_ID.public_cert_id = CL_CRT.internal_id
        JOIN public_cert SRV_CRT ON CL_ID.server_public_cert_id = SRV_CRT.internal_id
      WHERE CL_ID.user_account_id = userID;
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION get_client_identity(body JSON, urlArgument TEXT, sessionToken UUID) RETURNS JSON AS $$
  DECLARE
    userID INT;
  BEGIN
    userID := auth(sessionToken);
    RETURN json_build_object('clientIdentity', json_identity(CL_ID, CL_CRT, SRV_CRT))
      FROM client_identity CL_ID
        JOIN public_cert CL_CRT ON CL_ID.public_cert_id = CL_CRT.internal_id
        JOIN public_cert SRV_CRT ON CL_ID.server_public_cert_id = SRV_CRT.internal_id
      WHERE CL_ID.user_account_id = userID AND SRV_CRT.id = urlArgument::UUID;
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION post_client_identity(body JSON, sessionToken UUID) RETURNS VOID AS $$
  DECLARE
    userID INT;
    clientIdentity JSON;
    serverCertId INT;
    clientCertId INT;
    privateModulus BYTEA;
    privateExponent BYTEA;
  BEGIN
    userID := auth(sessionToken);
    clientIdentity := body->'clientIdentity';
    SELECT internal_id INTO serverCertId FROM public_cert WHERE id = ((clientIdentity->'server')->>'id')::UUID;
    IF FOUND THEN --if already exists, then replace/overwrite
      SELECT public_cert_id INTO clientCertId FROM client_identity WHERE user_account_id = userID AND server_public_cert_id = serverCertId;
      DELETE FROM client_identity WHERE user_account_id = userID AND server_public_cert_id = serverCertId;
      DELETE FROM public_cert WHERE internal_id = clientCertId;
    END IF;
    clientCertId := insert_public_cert(clientIdentity->'clientPublic');
    privateModulus := decode((clientIdentity->'clientPrivate')->>'modulus', 'base64');
    privateExponent := decode((clientIdentity->'clientPrivate')->>'exponent', 'base64');
    SELECT internal_id INTO serverCertId FROM public_cert WHERE id = ((clientIdentity->'server')->>'id')::UUID;
    IF NOT FOUND THEN
      serverCertId := insert_public_cert(clientIdentity->'server');
    END IF;
    INSERT INTO client_identity(user_account_id, public_cert_id, server_public_cert_id, private_cert_modulus, private_cert_exponent)
      VALUES (userID, clientCertID, serverCertId, privateModulus, privateExponent);
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
