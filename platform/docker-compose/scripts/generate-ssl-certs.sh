#!/bin/bash
set -ex

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOMAIN="localcontroller.taksa-factory.manufacturing"
CERT_DIR="config/certs"
DAYS_VALID=365

echo -e "${BLUE}Generating SSL Certificates for $DOMAIN${NC}\n"

mkdir -p "$CERT_DIR"

openssl genrsa -out "$CERT_DIR/server.key" 2048

cat > "$CERT_DIR/openssl.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C = IN
ST = Karnataka
L = Bengaluru
O = Taksa Factory
OU = Manufacturing
CN = $DOMAIN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
DNS.3 = localhost
DNS.4 = *.taksa-factory.manufacturing
IP.1 = 127.0.0.1
EOF

openssl req -new -key "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" \
  -config "$CERT_DIR/openssl.cnf"

openssl x509 -req -in "$CERT_DIR/server.csr" \
  -signkey "$CERT_DIR/server.key" \
  -out "$CERT_DIR/server.crt" \
  -days $DAYS_VALID \
  -extensions v3_req \
  -extfile "$CERT_DIR/openssl.cnf"

cat "$CERT_DIR/server.crt" "$CERT_DIR/server.key" > "$CERT_DIR/server.pem"

chmod 600 "$CERT_DIR/server.key" "$CERT_DIR/server.pem"
chmod 644 "$CERT_DIR/server.crt"

echo -e "${GREEN}✓ SSL certificates generated!${NC}"
openssl x509 -in "$CERT_DIR/server.crt" -noout -subject -dates
