#!/usr/bin/env bash
# Local-only smoke test: Supabase Auth + profiles RLS.
# Run from anywhere with the local stack up:  bash backend/scripts/auth_smoke_test.sh
# Creates throwaway users in the LOCAL database only. `supabase db reset` wipes them.
set -u

API="${API_URL:-http://127.0.0.1:54321}"
ANON="${ANON_KEY:-}"
PW="Passw0rd-test-123"

case "$API" in
  http://127.0.0.1*|http://localhost*) ;;
  *) echo "Refusing to run against non-local API: $API"; exit 1 ;;
esac

if [ -z "$ANON" ]; then
  ANON=$(cd "$(dirname "$0")/.." 2>/dev/null && supabase status -o env 2>/dev/null \
    | grep -E '^(ANON_KEY|PUBLISHABLE_KEY)=' | head -1 | cut -d= -f2- | tr -d '"')
fi
if [ -z "$ANON" ]; then
  echo "Could not find the anon key. Run 'supabase status' and re-run with ANON_KEY=<key> bash $0"
  exit 1
fi

jget() {
  python3 -c '
import sys, json
d = json.load(sys.stdin)
for k in sys.argv[1].split("."):
    d = d[k] if isinstance(d, dict) else d[int(k)]
print(d)' "$1" 2>/dev/null
}
jlen() {
  python3 -c '
import sys, json
d = json.load(sys.stdin)
print(len(d) if isinstance(d, list) else -1)' 2>/dev/null
}

PASS=0; FAIL=0
ok()   { echo "PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL  $1  ($2)"; FAIL=$((FAIL+1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected $2, got $3"; fi; }
is4xx() { case "$1" in 4??) return 0 ;; *) return 1 ;; esac; }

CODE=""; BODY=""
call() { # method url token [body]
  local method=$1 url=$2 token=$3 body=${4:-}
  local args=(-s -w '\n%{http_code}' -X "$method" "$url"
    -H "apikey: $ANON" -H "Content-Type: application/json" -H "Prefer: return=representation")
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  [ -n "$body" ] && args+=(-d "$body")
  local out; out=$(curl "${args[@]}")
  CODE=$(echo "$out" | tail -n1)
  BODY=$(echo "$out" | sed '$d')
}

TOKEN=""; USER_ID=""
signup_and_login() { # email
  call POST "$API/auth/v1/signup" "" "{\"email\":\"$1\",\"password\":\"$PW\"}"
  if [ "$CODE" != "200" ]; then echo "Signup failed ($CODE): $BODY"; exit 1; fi
  call POST "$API/auth/v1/token?grant_type=password" "" "{\"email\":\"$1\",\"password\":\"$PW\"}"
  if [ "$CODE" != "200" ]; then
    echo "Login failed ($CODE): $BODY"
    echo "If email confirmation is on, confirm at http://127.0.0.1:54324 or set enable_confirmations = false under [auth.email] in config.toml."
    exit 1
  fi
  TOKEN=$(echo "$BODY" | jget access_token)
  USER_ID=$(echo "$BODY" | jget user.id)
}

S=$(date +%s)

echo "== Auth: sign up and log in =="
signup_and_login "a_$S@test.dev"; A_TOKEN=$TOKEN; A_ID=$USER_ID
signup_and_login "b_$S@test.dev"; B_TOKEN=$TOKEN; B_ID=$USER_ID
signup_and_login "c_$S@test.dev"; C_TOKEN=$TOKEN; C_ID=$USER_ID
[ -n "$A_TOKEN" ] && [ -n "$A_ID" ] && ok "sign up + log in returns a token and user id" || bad "token/user id" "empty"

call POST "$API/auth/v1/token?grant_type=password" "" "{\"email\":\"a_$S@test.dev\",\"password\":\"wrong-password\"}"
is4xx "$CODE" && ok "wrong password is rejected ($CODE)" || bad "wrong password" "got $CODE"

call POST "$API/auth/v1/signup" "" "{\"email\":\"a_$S@test.dev\",\"password\":\"$PW\"}"
echo "INFO  duplicate email signup returned $CODE (informational; behavior depends on confirmation settings)"

echo "== Profiles: create own rows =="
call POST "$API/rest/v1/profiles" "$A_TOKEN" \
  "{\"user_id\":\"$A_ID\",\"username\":\"a_$S\",\"target_english\":650,\"target_math\":700,\"daily_goal\":10}"
check "A creates own profile" 201 "$CODE"

call POST "$API/rest/v1/profiles" "$B_TOKEN" \
  "{\"user_id\":\"$B_ID\",\"username\":\"b_$S\",\"target_english\":600,\"target_math\":600,\"daily_goal\":15,\"cohort\":\"volunteer\"}"
if [ "$CODE" = "201" ]; then
  check "cohort sent by client is not stored" "None" "$(echo "$BODY" | jget 0.cohort)"
elif is4xx "$CODE"; then
  ok "client-supplied cohort rejected outright ($CODE)"
else
  bad "cohort guard" "unexpected status $CODE"
fi

echo "== RLS: isolation =="
call GET "$API/rest/v1/profiles?select=username" "$A_TOKEN"
check "A sees exactly one profile (their own)" 1 "$(echo "$BODY" | jlen)"

call GET "$API/rest/v1/profiles?select=username" ""
if [ "$(echo "$BODY" | jlen)" = "0" ] || is4xx "$CODE"; then ok "anonymous reads nothing"; else bad "anon read" "code $CODE body $BODY"; fi

call PATCH "$API/rest/v1/profiles?user_id=eq.$B_ID" "$A_TOKEN" "{\"daily_goal\":99}"
if is4xx "$CODE" || [ "$(echo "$BODY" | jlen)" = "0" ]; then ok "A cannot update B's profile"; else bad "A updated B" "code $CODE body $BODY"; fi

call DELETE "$API/rest/v1/profiles?user_id=eq.$B_ID" "$A_TOKEN"
if is4xx "$CODE" || [ "$(echo "$BODY" | jlen)" = "0" ]; then ok "A cannot delete B's profile"; else bad "A deleted B" "code $CODE body $BODY"; fi

call GET "$API/rest/v1/profiles?select=daily_goal&user_id=eq.$B_ID" "$B_TOKEN"
check "B's profile is unchanged" 15 "$(echo "$BODY" | jget 0.daily_goal)"

echo "== RLS + constraints: bad writes =="
call POST "$API/rest/v1/profiles" "$C_TOKEN" \
  "{\"user_id\":\"$A_ID\",\"username\":\"c_$S\",\"target_english\":600,\"target_math\":600,\"daily_goal\":10}"
is4xx "$CODE" && ok "C cannot create a profile for A's user_id ($CODE)" || bad "spoofed user_id" "got $CODE"

call POST "$API/rest/v1/profiles" "$C_TOKEN" \
  "{\"user_id\":\"$C_ID\",\"username\":\"AB\",\"target_english\":600,\"target_math\":600,\"daily_goal\":10}"
is4xx "$CODE" && ok "invalid username rejected ($CODE)" || bad "bad username" "got $CODE"

call POST "$API/rest/v1/profiles" "$C_TOKEN" \
  "{\"user_id\":\"$C_ID\",\"username\":\"c_$S\",\"target_english\":655,\"target_math\":600,\"daily_goal\":10}"
is4xx "$CODE" && ok "score not divisible by 10 rejected ($CODE)" || bad "bad score" "got $CODE"

call POST "$API/rest/v1/profiles" "$C_TOKEN" \
  "{\"user_id\":\"$C_ID\",\"username\":\"a_$S\",\"target_english\":600,\"target_math\":600,\"daily_goal\":10}"
is4xx "$CODE" && ok "duplicate username rejected ($CODE)" || bad "duplicate username" "got $CODE"

echo "== is_username_available() =="
call POST "$API/rest/v1/rpc/is_username_available" "$C_TOKEN" "{\"candidate\":\"a_$S\"}"
check "taken username reports unavailable" "false" "$(echo "$BODY" | tr -d '[:space:]')"
call POST "$API/rest/v1/rpc/is_username_available" "$C_TOKEN" "{\"candidate\":\"free_$S\"}"
check "unused username reports available" "true" "$(echo "$BODY" | tr -d '[:space:]')"
call POST "$API/rest/v1/rpc/is_username_available" "" "{\"candidate\":\"free_$S\"}"
check "anonymous callers can check availability" "200" "$CODE"

echo
echo "Result: $PASS passed, $FAIL failed"
echo "Not covered: email-confirmation links, password reset, and the register-entry / grade-attempt Edge Functions."
[ "$FAIL" -eq 0 ]
