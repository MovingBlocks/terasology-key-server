# API specification

The checkbox indicates whether an action has been implemented (checked) or is planned (unchecked).

## /api/user_account
- [x] POST: register a new user.

## /api/session
- [x] POST: given username and password, creates a new session (login with a new client); returns a session token.

### /api/session/{sessionToken}
- [x] GET: returns information about the session's owner (e.g. user name)
- [x] DELETE: forces expiration of a session, given the token (logout).

## /api/client_identity
- [x] GET: given a session token, returns all the client identities for the user which owns the session
- [x] POST: given a session token, a server public certificate and a client identity, stores the client identity associated with the specified server for the user which owns the session.

### /api/client_identity/{serverID}
- [x] GET: given a session token and a server ID, returns the identity of the user which owns the session on the specified server.
