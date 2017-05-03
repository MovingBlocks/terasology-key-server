-- stored procedures intended to be called by the app user

-- user_account
CREATE FUNCTION post_user_account(body JSON) RETURNS VOID AS $$
  BEGIN
    IF (body->>'password1') <> (body->>'password2') THEN
      RAISE EXCEPTION 'Passwords do not match';
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
      RAISE EXCEPTION 'Invalid login or password';
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
