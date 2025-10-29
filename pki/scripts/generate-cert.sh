#!/bin/bash

# Certificate Generation Script
# Generates service certificates signed by Intermediate CA

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKI_DIR="$(dirname "$SCRIPT_DIR")"
CA_DIR="$PKI_DIR/ca"
CERTS_DIR="$PKI_DIR/certs"

# Load environment variables
if [ -f "$PKI_DIR/../../.env" ]; then
    source "$PKI_DIR/../../.env"
fi

SERVICE_NAME="${1}"
SERVICE_CERT_VALIDITY="${SERVICE_CERT_VALIDITY:-90}"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service-name>"
    echo "Example: $0 flask-app"
    exit 1
fi

echo "==================================="
echo "Generating Certificate: $SERVICE_NAME"
echo "==================================="
echo ""

# Create output directory
mkdir -p "$CERTS_DIR/$SERVICE_NAME"

echo "[1/4] Generating private key..."
echo "TODO: Generate service private key"
echo ""

echo "[2/4] Creating Certificate Signing Request..."
echo "TODO: Create CSR for $SERVICE_NAME"
echo ""

echo "[3/4] Signing certificate with Intermediate CA..."
echo "TODO: Sign CSR with Intermediate CA"
echo "  - Validity: $SERVICE_CERT_VALIDITY days"
echo ""

echo "[4/4] Creating full certificate chain..."
echo "TODO: Bundle service cert with intermediate and root"
echo ""

echo "==================================="
echo "Certificate Generated!"
echo "==================================="
echo ""
echo "Certificate files:"
echo "  Private key: $CERTS_DIR/$SERVICE_NAME/$SERVICE_NAME.key"
echo "  Certificate: $CERTS_DIR/$SERVICE_NAME/$SERVICE_NAME.crt"
echo "  Full chain:  $CERTS_DIR/$SERVICE_NAME/$SERVICE_NAME-chain.crt"
echo ""
