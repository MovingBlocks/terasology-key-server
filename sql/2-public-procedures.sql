-- stored procedures intended to be called by the app user

CREATE FUNCTION post_user_account(login VARCHAR(40), password1 CHAR(64), password2 CHAR(64)) RETURNS VOID AS $$
  BEGIN
    IF password1 <> password2 THEN
      RAISE EXCEPTION 'Passwords do not match';
    END IF;
    INSERT INTO user_account (login, password) VALUES ($1, $2);
  END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
