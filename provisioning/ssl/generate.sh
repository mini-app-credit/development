#!/bin/sh
set -e

DOMAIN="${DOMAIN_NAME:-mini-credit.local}"
SSL_DIR="$(dirname "$0")/../../deployment/ssl"

mkdir -p "$SSL_DIR"

if ! command -v mkcert >/dev/null 2>&1; then
  echo "Error: mkcert is not installed. Run: brew install mkcert"
  exit 1
fi

# Install CA into system trust store (requires sudo once)
mkcert -install

# Generate wildcard + root certificate
mkcert \
  -cert-file "$SSL_DIR/cert.pem" \
  -key-file "$SSL_DIR/key.pem" \
  "$DOMAIN" "*.$DOMAIN"

# Copy mkcert CA for local tooling (optional)
CA_ROOT="$(mkcert -CAROOT)"
cp "$CA_ROOT/rootCA.pem" "$SSL_DIR/ca.pem"

echo ""
echo "SSL certificates generated in $SSL_DIR:"
ls -la "$SSL_DIR"
echo ""
echo "Domains: $DOMAIN, *.$DOMAIN"
