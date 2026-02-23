#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/create-lifetime-key.sh [friend@example.com]   — create a gift code
#   ./scripts/create-lifetime-key.sh --batch 5               — pre-generate 5 gift codes
#   ./scripts/create-lifetime-key.sh --key GIFTXXXXXXXX      — retrieve the license key after redemption
#   ./scripts/create-lifetime-key.sh --list                   — list existing GIFT discounts
#   ./scripts/create-lifetime-key.sh --cleanup                — delete unredeemed GIFT discounts older than 7 days

CHECKOUT_BASE="https://thinkur.lemonsqueezy.com/checkout/buy/e6442da0-dce6-45cc-a903-a39d9bedb167"

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

API="https://api.lemonsqueezy.com/v1"
AUTH="Authorization: Bearer $LSKEY"
ACCEPT="Accept: application/vnd.api+json"

# ─── --key: retrieve license key for a redeemed gift code ───

if [[ "${1:-}" == "--key" ]]; then
    CODE="${2:?Usage: $0 --key GIFTXXXXXXXX}"

    echo "→ Looking up discount for code: $CODE"
    DISCOUNT_ID=$(curl -s "$API/discounts" -H "$AUTH" -H "$ACCEPT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for d in data['data']:
    if d['attributes']['code'] == '$CODE':
        print(d['id'])
        sys.exit(0)
print('NOT_FOUND')
sys.exit(1)
" 2>/dev/null) || { echo "Error: Discount code $CODE not found"; exit 1; }

    echo "  Discount ID: $DISCOUNT_ID"
    echo "→ Checking redemptions..."
    REDEMPTION_INFO=$(curl -s "$API/discount-redemptions?filter[discount_id]=$DISCOUNT_ID" -H "$AUTH" -H "$ACCEPT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not data['data']:
    print('NOT_REDEEMED')
    sys.exit(0)
r = data['data'][0]
order_id = r['attributes']['order_id']
print(order_id)
")

    if [[ "$REDEMPTION_INFO" == "NOT_REDEEMED" ]]; then
        echo "  Not redeemed yet."
        exit 0
    fi

    ORDER_ID="$REDEMPTION_INFO"
    echo "  Order ID: $ORDER_ID"
    echo "→ Looking up license key..."
    LICENSE_KEY=$(curl -s "$API/license-keys?filter[order_id]=$ORDER_ID" -H "$AUTH" -H "$ACCEPT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not data['data']:
    print('NO_KEY', file=sys.stderr)
    sys.exit(1)
print(data['data'][0]['attributes']['key'])
")

    if [[ -z "$LICENSE_KEY" ]]; then
        echo "Error: No license key found for order $ORDER_ID"
        exit 1
    fi

    echo ""
    echo "=== License Key ==="
    echo "$LICENSE_KEY"
    exit 0
fi

# ─── --list: show existing GIFT discounts ───

if [[ "${1:-}" == "--list" ]]; then
    echo "→ Fetching GIFT discounts..."
    curl -s "$API/discounts" -H "$AUTH" -H "$ACCEPT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
gifts = [d for d in data['data'] if d['attributes']['code'].startswith('GIFT')]
if not gifts:
    print('  No GIFT discounts found.')
    sys.exit(0)
print(f'  Found {len(gifts)} GIFT discount(s):')
print()
for d in gifts:
    a = d['attributes']
    code = a['code']
    name = a.get('name', '')
    redemptions = a.get('redemptions_count', 0)
    max_r = a.get('max_redemptions', '∞')
    created = a.get('created_at', 'unknown')[:10]
    status = '✓ redeemed' if redemptions > 0 else '  unused'
    print(f'  {status}  {code}  ({name})  {redemptions}/{max_r} redemptions  created {created}')
"
    exit 0
fi

# ─── --batch: pre-generate multiple gift codes ───

if [[ "${1:-}" == "--batch" ]]; then
    COUNT="${2:?Usage: $0 --batch N}"
    if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [[ "$COUNT" -lt 1 ]]; then
        echo "Error: batch count must be a positive number"
        exit 1
    fi

    echo "→ Looking up store ID..."
    STORE_ID=$(curl -s "$API/stores" -H "$AUTH" -H "$ACCEPT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['data'][0]['id'])
")

    echo "→ Looking up lifetime variant..."
    VARIANT_ID=$(curl -s "$API/variants" -H "$AUTH" -H "$ACCEPT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for v in data['data']:
    if not v['attributes'].get('is_subscription', False):
        print(v['id'])
        sys.exit(0)
sys.exit(1)
")

    echo "→ Generating $COUNT gift codes..."
    echo ""
    CODES=()
    for ((i = 1; i <= COUNT; i++)); do
        CODE="GIFT$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')"
        RESP=$(curl -s -X POST "$API/discounts" \
            -H "$AUTH" \
            -H "$ACCEPT" \
            -H "Content-Type: application/vnd.api+json" \
            -d "{
                \"data\": {
                    \"type\": \"discounts\",
                    \"attributes\": {
                        \"name\": \"Gift key (batch)\",
                        \"code\": \"$CODE\",
                        \"amount\": 100,
                        \"amount_type\": \"percent\",
                        \"is_limited_to_products\": true,
                        \"is_limited_redemptions\": true,
                        \"max_redemptions\": 1
                    },
                    \"relationships\": {
                        \"store\": {
                            \"data\": { \"type\": \"stores\", \"id\": \"$STORE_ID\" }
                        },
                        \"variants\": {
                            \"data\": [{ \"type\": \"variants\", \"id\": \"$VARIANT_ID\" }]
                        }
                    }
                }
            }")
        # Check for errors
        echo "$RESP" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'errors' in data:
    for e in data['errors']:
        print(f\"Error creating code $i: {e.get('detail', e)}\", file=sys.stderr)
    sys.exit(1)
" || exit 1
        CODES+=("$CODE")
        echo "  [$i/$COUNT] $CODE"
    done

    echo ""
    echo "=== $COUNT Gift Codes Ready ==="
    echo "Checkout URL (same for all): $CHECKOUT_BASE"
    echo ""
    echo "Codes (one per friend, single-use):"
    for C in "${CODES[@]}"; do
        echo "  $C"
    done
    echo ""
    echo "Tell your friend: go to the checkout URL, enter the code at payment."
    exit 0
fi

# ─── --cleanup: delete unredeemed GIFT discounts older than 7 days ───

if [[ "${1:-}" == "--cleanup" ]]; then
    echo "→ Finding old unredeemed GIFT discounts..."
    TO_DELETE=$(curl -s "$API/discounts" -H "$AUTH" -H "$ACCEPT" | python3 -c "
import sys, json
from datetime import datetime, timezone, timedelta
data = json.load(sys.stdin)
cutoff = datetime.now(timezone.utc) - timedelta(days=7)
ids = []
for d in data['data']:
    a = d['attributes']
    if not a['code'].startswith('GIFT'):
        continue
    if a.get('redemptions_count', 0) > 0:
        continue
    created = datetime.fromisoformat(a['created_at'].replace('Z', '+00:00'))
    if created < cutoff:
        ids.append((d['id'], a['code'], a['created_at'][:10]))
if not ids:
    print('NONE')
else:
    for id, code, date in ids:
        print(f'{id}|{code}|{date}')
")

    if [[ "$TO_DELETE" == "NONE" ]]; then
        echo "  No old unredeemed GIFT discounts to clean up."
        exit 0
    fi

    COUNT=0
    while IFS='|' read -r ID CODE DATE; do
        echo "  Deleting $CODE (created $DATE)..."
        curl -s -X DELETE "$API/discounts/$ID" -H "$AUTH" -H "$ACCEPT" > /dev/null
        COUNT=$((COUNT + 1))
    done <<< "$TO_DELETE"

    echo "  Deleted $COUNT discount(s)."
    exit 0
fi

# ─── Default: create a gift link ───

EMAIL="${1:-}"

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
    attrs = v['attributes']
    is_subscription = attrs.get('is_subscription', False)
    if not is_subscription:
        print(v['id'])
        sys.exit(0)
print('NOT_FOUND', file=sys.stderr)
for v in data['data']:
    a = v['attributes']
    print(f\"  {v['id']}: {a.get('name', 'unnamed')} (subscription={a.get('is_subscription', '?')})\", file=sys.stderr)
sys.exit(1)
")
echo "  Variant: $VARIANT_ID"

# Create a single-use 100% discount
CODE="GIFT$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')"
echo "→ Creating 100% discount code: $CODE"
DISCOUNT_RESPONSE=$(curl -s -X POST "$API/discounts" \
    -H "$AUTH" \
    -H "$ACCEPT" \
    -H "Content-Type: application/vnd.api+json" \
    -d "{
        \"data\": {
            \"type\": \"discounts\",
            \"attributes\": {
                \"name\": \"Gift key${EMAIL:+ for $EMAIL}\",
                \"code\": \"$CODE\",
                \"amount\": 100,
                \"amount_type\": \"percent\",
                \"is_limited_to_products\": true,
                \"is_limited_redemptions\": true,
                \"max_redemptions\": 1
            },
            \"relationships\": {
                \"store\": {
                    \"data\": { \"type\": \"stores\", \"id\": \"$STORE_ID\" }
                },
                \"variants\": {
                    \"data\": [{ \"type\": \"variants\", \"id\": \"$VARIANT_ID\" }]
                }
            }
        }
    }")

# Check discount creation succeeded
echo "$DISCOUNT_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'errors' in data:
    for e in data['errors']:
        print(f\"Error: {e.get('detail', e)}\", file=sys.stderr)
    sys.exit(1)
" || exit 1

echo ""
echo "=== Done ==="
echo "Checkout: $CHECKOUT_BASE"
echo "Code:     $CODE  (single-use)"
echo ""
echo "Send both${EMAIL:+ to $EMAIL} — they enter the code at checkout."
