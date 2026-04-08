#!/usr/bin/env bash
#
# Creates a self-signed "Yap Developer" code signing certificate.
# This ensures a stable code signature across builds so macOS TCC
# (accessibility permissions) persists through app updates.
#
# Usage:
#   ./installer/create_signing_cert.sh
#
# Outputs:
#   /tmp/yap-codesign.p12   - PKCS12 bundle (import to keychain / use in CI)
#   Base64-encoded .p12 printed to stdout for GitHub Actions secrets
#
# After running, add these GitHub repository secrets:
#   MACOS_CERTIFICATE_B64  = the base64 output
#   MACOS_CERTIFICATE_PWD  = the password printed below
#
set -euo pipefail

CERT_CN="Yap Developer"
CERT_ORG="Yap"
CERT_DAYS=3650
CERT_PASSWORD="yap-codesign-export"

TMPDIR_CERT="$(mktemp -d)"
KEY_FILE="$TMPDIR_CERT/yap-codesign.key"
CRT_FILE="$TMPDIR_CERT/yap-codesign.crt"
P12_FILE="/tmp/yap-codesign.p12"
CONF_FILE="$TMPDIR_CERT/cert.conf"

echo "==> Generating self-signed code signing certificate: \"$CERT_CN\""

# OpenSSL config with code signing extensions
cat > "$CONF_FILE" << EOF
[req]
distinguished_name = req_dn
x509_extensions = codesign_ext
prompt = no

[req_dn]
CN = $CERT_CN
O = $CERT_ORG

[codesign_ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = codeSigning
basicConstraints = critical, CA:FALSE
EOF

# Generate key + certificate
openssl req -x509 -newkey rsa:2048 \
  -keyout "$KEY_FILE" -out "$CRT_FILE" \
  -days "$CERT_DAYS" -nodes \
  -config "$CONF_FILE" 2>/dev/null

echo "==> Certificate created (valid $CERT_DAYS days)"
openssl x509 -in "$CRT_FILE" -noout -subject -dates

# Export as .p12 (use -legacy for macOS compatibility with OpenSSL 3.x)
LEGACY_FLAG=""
if openssl version | grep -q "^OpenSSL 3"; then
  LEGACY_FLAG="-legacy"
fi

openssl pkcs12 -export \
  -out "$P12_FILE" \
  -inkey "$KEY_FILE" -in "$CRT_FILE" \
  -password "pass:$CERT_PASSWORD" \
  $LEGACY_FLAG 2>/dev/null

echo "==> Exported: $P12_FILE (password: $CERT_PASSWORD)"

# Import to local keychain
echo ""
echo "==> Importing to login keychain..."
security import "$P12_FILE" \
  -k ~/Library/Keychains/login.keychain-db \
  -P "$CERT_PASSWORD" \
  -T /usr/bin/codesign 2>/dev/null && echo "   Imported successfully" || echo "   Already exists or import failed"

# Trust for code signing
security add-trusted-cert -p codeSign \
  -k ~/Library/Keychains/login.keychain-db \
  "$CRT_FILE" 2>/dev/null && echo "   Trusted for code signing" || echo "   Trust already set or failed"

# Verify it shows up
echo ""
echo "==> Verifying codesign identity:"
security find-identity -v -p codesigning | grep "$CERT_CN" || echo "   WARNING: Identity not found"

# Base64 for GitHub Actions
echo ""
echo "=========================================="
echo "GitHub Actions secrets:"
echo "=========================================="
echo ""
echo "MACOS_CERTIFICATE_PWD = $CERT_PASSWORD"
echo ""
echo "MACOS_CERTIFICATE_B64 = (copy everything between the markers below)"
echo ""
echo "--- BEGIN BASE64 ---"
base64 -i "$P12_FILE"
echo "--- END BASE64 ---"

# Cleanup temp files (but keep .p12)
rm -rf "$TMPDIR_CERT"

echo ""
echo "Done. Certificate files cleaned up, .p12 at $P12_FILE"
