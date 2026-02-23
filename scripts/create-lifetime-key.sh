#!/usr/bin/env bash
set -euo pipefail

# Usage: LSKEY=your_api_key ./scripts/create-lifetime-key.sh friend@example.com

# Load .env if present
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a && source "$SCRIPT_DIR/.env" && set +a
fi

if [[ -z "${LSKEY:-}" ]]; then
    echo "Error: Set LSKEY environment variable with your LemonSqueezy API key"
    echo "  Get it at: https://app.lemonsqueezy.com/settings/api (live mode!)"
    echo ""
    echo "Usage: LSKEY=lmsq_... ./scripts/create-lifetime-key.sh [friend@example.com]"
    exit 1
fi

EMAIL="${1:-}"

API="https://api.lemonsqueezy.com/v1"
AUTH="Authorization: Bearer $LSKEY"
ACCEPT="Accept: application/vnd.api+json"

echo "→ Looking up store ID..."
STORE_ID=$(curl -s "$API/stores" -H "$AUTH" -H "$ACCEPT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['data'][0]['id'])
")
echo "  Store: $STORE_ID"

echo "→ Looking up lifetime variant..."
VARIANT_ID=$(curl -s "$API/variants" -H "$AUTH" -H "$ACCEPT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for v in data['data']:
    name = v['attributes'].get('name', '').lower()
    if 'lifetime' in name or 'one-time' in name:
        print(v['id'])
        sys.exit(0)
# fallback: just list them so user can pick
print('NOT_FOUND', file=sys.stderr)
for v in data['data']:
    print(f\"  {v['id']}: {v['attributes'].get('name', 'unnamed')}\", file=sys.stderr)
sys.exit(1)
")
echo "  Variant: $VARIANT_ID"

EXPIRES=$(date -u -v+7d '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d '+7 days' '+%Y-%m-%dT%H:%M:%SZ')

EMAIL_JSON=""
if [[ -n "$EMAIL" ]]; then
    EMAIL_JSON="\"checkout_data\": { \"email\": \"$EMAIL\" },"
fi

echo "→ Creating free checkout${EMAIL:+ for $EMAIL} (expires in 7 days)..."
RESPONSE=$(curl -s -X POST "$API/checkouts" \
    -H "$AUTH" \
    -H "$ACCEPT" \
    -H "Content-Type: application/vnd.api+json" \
    -d "{
        \"data\": {
            \"type\": \"checkouts\",
            \"attributes\": {
                \"custom_price\": 0,
                $EMAIL_JSON
                \"expires_at\": \"$EXPIRES\"
            },
            \"relationships\": {
                \"store\": {
                    \"data\": { \"type\": \"stores\", \"id\": \"$STORE_ID\" }
                },
                \"variant\": {
                    \"data\": { \"type\": \"variants\", \"id\": \"$VARIANT_ID\" }
                }
            }
        }
    }")

URL=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'errors' in data:
    for e in data['errors']:
        print(f\"Error: {e.get('detail', e)}\", file=sys.stderr)
    sys.exit(1)
print(data['data']['attributes']['url'])
")

echo ""
echo "=== Done ==="
echo "Send this link to $EMAIL:"
echo "$URL"
