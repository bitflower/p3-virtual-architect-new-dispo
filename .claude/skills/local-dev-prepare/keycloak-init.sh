#!/bin/bash
# Configures Keycloak master realm with clients required by the New Dispo stack.
# Run after Keycloak is healthy.

set -e

KC_URL="${KC_URL:-http://localhost:8080}"
KC_ADMIN="${KC_ADMIN:-admin}"
KC_PASSWORD="${KC_PASSWORD:-admin}"

echo "Waiting for Keycloak at $KC_URL..."
for i in $(seq 1 30); do
  if curl -sf "$KC_URL/realms/master" > /dev/null 2>&1; then
    echo "Keycloak is ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Keycloak did not become ready in time."
    exit 1
  fi
  sleep 2
done

echo "Obtaining admin token..."
TOKEN=$(curl -sf -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$KC_ADMIN&password=$KC_PASSWORD&grant_type=password&client_id=admin-cli" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to obtain admin token."
  exit 1
fi

echo "Setting access token lifespan to 30 minutes..."
code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$KC_URL/admin/realms/master" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"accessTokenLifespan": 1800}')
if [ "$code" = "204" ]; then
  echo "  ✓ Token lifespan set to 1800s (30m)"
else
  echo "  ✗ Failed to set token lifespan (HTTP $code)"
fi

create_client() {
  local json="$1"
  local name
  name=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['clientId'])")

  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KC_URL/admin/realms/master/clients" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$json")

  if [ "$code" = "201" ]; then
    echo "  ✓ $name created"
  elif [ "$code" = "409" ]; then
    echo "  - $name already exists"
  else
    echo "  ✗ $name failed (HTTP $code)"
  fi
}

echo "Creating clients..."

# Frontend: public client for browser-based auth
create_client '{
  "clientId": "client-test",
  "enabled": true,
  "publicClient": true,
  "directAccessGrantsEnabled": true,
  "standardFlowEnabled": true,
  "redirectUris": ["http://localhost:4200/*", "http://localhost:5101/*"],
  "webOrigins": ["*"],
  "protocol": "openid-connect"
}'

# Backend: confidential client with service account
create_client '{
  "clientId": "client-credentials-test",
  "enabled": true,
  "publicClient": false,
  "serviceAccountsEnabled": true,
  "directAccessGrantsEnabled": true,
  "standardFlowEnabled": true,
  "redirectUris": ["*"],
  "webOrigins": ["*"],
  "protocol": "openid-connect",
  "secret": "test-secret"
}'

# TMS Bridge audiences
create_client '{
  "clientId": "tms-cloud-service",
  "enabled": true,
  "publicClient": false,
  "bearerOnly": true,
  "protocol": "openid-connect"
}'

create_client '{
  "clientId": "ebv-client",
  "enabled": true,
  "publicClient": false,
  "bearerOnly": true,
  "protocol": "openid-connect"
}'

echo "Creating test user..."
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KC_URL/admin/realms/master/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "enabled": true,
    "emailVerified": true,
    "firstName": "Test",
    "lastName": "User",
    "email": "test@local.dev",
    "credentials": [{"type": "password", "value": "test", "temporary": false}]
  }')

if [ "$code" = "201" ]; then
  echo "  ✓ testuser created (password: test)"
elif [ "$code" = "409" ]; then
  echo "  - testuser already exists"
else
  echo "  ✗ testuser failed (HTTP $code)"
fi

echo "Assigning roles to testuser..."
USER_ID=$(curl -s "$KC_URL/admin/realms/master/users?username=testuser" \
  -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")

ACCOUNT_CLIENT_ID=$(curl -s "$KC_URL/admin/realms/master/clients?clientId=account" \
  -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")

for role_name in manage-account-links manage-account view-profile; do
  role_json=$(curl -s "$KC_URL/admin/realms/master/clients/$ACCOUNT_CLIENT_ID/roles/$role_name" \
    -H "Authorization: Bearer $TOKEN")
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$KC_URL/admin/realms/master/users/$USER_ID/role-mappings/clients/$ACCOUNT_CLIENT_ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "[$role_json]")
  if [ "$code" = "204" ]; then
    echo "  ✓ $role_name assigned"
  elif [ "$code" = "409" ]; then
    echo "  - $role_name already assigned"
  else
    echo "  ✗ $role_name failed (HTTP $code)"
  fi
done

echo ""
echo "Keycloak configured."
echo "  Admin console: $KC_URL/admin/master/console/"
echo "  Credentials:   admin / admin"
echo "  Test user:     testuser / test (roles: manage-account-links, manage-account, view-profile)"
