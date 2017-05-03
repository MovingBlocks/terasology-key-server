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
