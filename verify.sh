#!/usr/bin/env bash
# Post-deploy checks for the New North Ventures BIMI logo URL.
# Usage: ./verify.sh [url]
set -uo pipefail

URL="${1:-https://bimi.newnorthvc.com/logo.svg}"
WANT_SHA="e75d249117052798183d73a39f3b69d5810ad56a73cf5022010fd1e0009d1806"
WANT_BYTES=1676
pass=0; fail=0
ok(){ echo "  PASS  $1"; pass=$((pass+1)); }
no(){ echo "  FAIL  $1"; fail=$((fail+1)); }

echo "Checking $URL"
echo

hdr=$(curl -sS -D - -o /tmp/bimi.$$ --max-time 20 "$URL" 2>/dev/null)
code=$(printf '%s' "$hdr" | awk '/^HTTP\//{c=$2} END{print c}')
ctype=$(printf '%s' "$hdr" | tr -d '\r' | awk -F': ' 'tolower($1)=="content-type"{print tolower($2)}' | tail -1)

# 1. direct 200, no redirect
if [ "$code" = "200" ]; then ok "HTTP 200 (direct)"
else no "expected HTTP 200, got ${code:-no response}"; fi

if printf '%s' "$hdr" | grep -qE '^HTTP/[0-9.]+ 30[128]'; then
  no "a redirect is present — mailbox providers do NOT follow redirects"
else ok "no 30x redirect in the chain"; fi

# 2. exact content type
case "$ctype" in
  image/svg+xml*) ok "Content-Type: $ctype" ;;
  "")             no "no Content-Type header" ;;
  *)              no "Content-Type is '$ctype', must be image/svg+xml" ;;
esac

# 3. HTTPS with a valid chain
if curl -sS --max-time 20 -o /dev/null "$URL" 2>/dev/null; then ok "TLS chain validates"
else no "TLS validation failed"; fi

# 4. byte integrity + size ceiling
if [ -s /tmp/bimi.$$ ]; then
  got_sha=$(sha256sum /tmp/bimi.$$ | cut -d' ' -f1)
  got_bytes=$(wc -c < /tmp/bimi.$$ | tr -d ' ')
  [ "$got_sha" = "$WANT_SHA" ] && ok "SHA-256 matches the frozen mark" \
    || no "SHA-256 MISMATCH — served file is not the certified artwork
          got  $got_sha
          want $WANT_SHA"
  [ "$got_bytes" = "$WANT_BYTES" ] && ok "size $got_bytes bytes" \
    || no "size is $got_bytes bytes, expected $WANT_BYTES"
  [ "$got_bytes" -lt 32768 ] && ok "under the 32 KB ceiling" || no "exceeds 32 KB"
else
  no "empty response body"
fi
rm -f /tmp/bimi.$$

echo
if [ "$fail" -eq 0 ]; then
  echo "ALL $pass CHECKS PASSED — safe to put this URL in the BIMI record."
else
  echo "$fail CHECK(S) FAILED, $pass passed — do NOT publish the DNS record yet."
  exit 1
fi
