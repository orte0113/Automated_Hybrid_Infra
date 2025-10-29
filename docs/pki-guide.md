# PKI Setup Guide

## Overview

This guide walks through the Public Key Infrastructure (PKI) implementation for the platform. We use a three-tier certificate authority structure for maximum security and flexibility.

## PKI Architecture

### Three-Tier Structure

```
Root CA (Offline, 10 years)
    │
    └─► Intermediate CA (Online, 5 years)
            │
            ├─► flask-app.crt (90 days)
            ├─► nginx.crt (90 days)
            ├─► postgres.crt (90 days)
            └─► [other services]
```

### Why Three-Tier?

- **Security**: Root CA can be kept offline
- **Flexibility**: Intermediate CA can be revoked without affecting root
- **Best Practice**: Follows industry standards
- **Operational**: Easier to manage service certificates

## Initial Setup

### Prerequisites

```bash
# Install OpenSSL
sudo apt-get install openssl

# Verify installation
openssl version
```

### Step 1: Initialize PKI Structure

```bash
cd pki/scripts
./setup-ca.sh
```

This creates:
```
pki/
├── ca/
│   ├── root/
│   │   ├── private/     # Root CA private key (SECURE!)
│   │   ├── certs/       # Root CA certificate
│   │   ├── index.txt    # Certificate database
│   │   └── serial       # Serial number tracker
│   └── intermediate/
│       ├── private/     # Intermediate CA private key
│       ├── certs/       # Intermediate CA certificate
│       ├── index.txt    # Certificate database
│       └── serial       # Serial number tracker
└── certs/              # Service certificates
```

### Step 2: Generate Root CA

**Manual process (if not automated):**

```bash
cd pki/ca/root

# Generate Root CA private key (4096-bit for extra security)
openssl genrsa -aes256 -out private/ca.key 4096
chmod 400 private/ca.key

# Create Root CA certificate (self-signed, 10 years)
openssl req -config ../../config/openssl.cnf \
  -key private/ca.key \
  -new -x509 -days 3650 -sha256 \
  -extensions v3_ca \
  -out certs/ca.crt

# Verify
openssl x509 -noout -text -in certs/ca.crt
```

### Step 3: Generate Intermediate CA

```bash
cd pki/ca/intermediate

# Generate Intermediate CA private key
openssl genrsa -aes256 -out private/intermediate.key 4096
chmod 400 private/intermediate.key

# Create certificate signing request (CSR)
openssl req -config ../../config/openssl.cnf \
  -key private/intermediate.key \
  -new -sha256 \
  -out csr/intermediate.csr

# Sign with Root CA
cd ../root
openssl ca -config ../../config/openssl.cnf \
  -extensions v3_intermediate_ca \
  -days 1825 -notext -md sha256 \
  -in ../intermediate/csr/intermediate.csr \
  -out ../intermediate/certs/intermediate.crt

# Verify
openssl x509 -noout -text -in ../intermediate/certs/intermediate.crt
openssl verify -CAfile certs/ca.crt ../intermediate/certs/intermediate.crt

# Create certificate chain
cat ../intermediate/certs/intermediate.crt certs/ca.crt > \
  ../intermediate/certs/ca-chain.crt
```

## Generating Service Certificates

### Quick Method

```bash
cd pki/scripts
./generate-cert.sh [service-name]
```

### Manual Method

```bash
cd pki/ca/intermediate

# Generate service private key
openssl genrsa -out ../../certs/[service-name]/[service-name].key 2048
chmod 400 ../../certs/[service-name]/[service-name].key

# Create CSR
openssl req -config ../../config/openssl.cnf \
  -key ../../certs/[service-name]/[service-name].key \
  -new -sha256 \
  -out ../../certs/[service-name]/[service-name].csr

# Sign with Intermediate CA
openssl ca -config ../../config/openssl.cnf \
  -extensions server_cert \
  -days 90 -notext -md sha256 \
  -in ../../certs/[service-name]/[service-name].csr \
  -out ../../certs/[service-name]/[service-name].crt

# Create full chain
cat ../../certs/[service-name]/[service-name].crt \
    certs/intermediate.crt \
    ../root/certs/ca.crt > \
    ../../certs/[service-name]/[service-name]-chain.crt
```

## Service-Specific Setup

### Nginx with SSL/TLS

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/nginx/certs/nginx-chain.crt;
    ssl_certificate_key /etc/nginx/certs/nginx.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # ... rest of config
}
```

### Flask with SSL/TLS

```python
from flask import Flask
app = Flask(__name__)

if __name__ == '__main__':
    app.run(
        ssl_context=(
            '/app/certs/flask-app-chain.crt',
            '/app/certs/flask-app.key'
        )
    )
```

### PostgreSQL with SSL/TLS

```bash
# In postgresql.conf
ssl = on
ssl_cert_file = '/var/lib/postgresql/certs/postgres.crt'
ssl_key_file = '/var/lib/postgresql/certs/postgres.key'
ssl_ca_file = '/var/lib/postgresql/certs/ca-chain.crt'
```

## Certificate Management

### Viewing Certificate Information

```bash
# View certificate details
openssl x509 -in pki/certs/[service]/[service].crt -noout -text

# Check expiration date
openssl x509 -in pki/certs/[service]/[service].crt -noout -enddate

# Verify certificate chain
openssl verify -CAfile pki/ca/root/certs/ca.crt \
  -untrusted pki/ca/intermediate/certs/intermediate.crt \
  pki/certs/[service]/[service].crt
```

### Certificate Renewal

**When to renew:**
- 30 days before expiration (warning)
- 7 days before expiration (critical)

**Renewal process:**
```bash
# Generate new certificate
cd pki/scripts
./generate-cert.sh [service-name]

# Backup old certificate
cp pki/certs/[service]/[service].crt \
   pki/certs/[service]/[service].crt.old

# Replace certificate (already done by script)
# Restart service
docker-compose restart [service-name]

# Verify new certificate
openssl s_client -connect localhost:443 -servername [service]
```

### Certificate Revocation

```bash
cd pki/ca/intermediate

# Revoke certificate
openssl ca -config ../../config/openssl.cnf \
  -revoke ../../certs/[service]/[service].crt

# Generate Certificate Revocation List (CRL)
openssl ca -config ../../config/openssl.cnf \
  -gencrl -out crl/intermediate.crl
```

## Automated Certificate Management

### Monitoring with Prometheus

```yaml
# In prometheus.yml
scrape_configs:
  - job_name: 'certificate-exporter'
    static_configs:
      - targets: ['certificate-exporter:9117']
```

### Automated Renewal Script

```bash
#!/bin/bash
# check-certs.sh - Run daily via cron

CERT_DIR="/path/to/pki/certs"
WARNING_DAYS=30

for cert in $CERT_DIR/*/*.crt; do
    expiry=$(openssl x509 -enddate -noout -in "$cert" | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry" +%s)
    now_epoch=$(date +%s)
    days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
    
    if [ $days_left -lt $WARNING_DAYS ]; then
        echo "Certificate $cert expires in $days_left days!"
        # Trigger renewal or send alert
    fi
done
```

### Cron Job Setup

```bash
# Add to crontab
crontab -e

# Run daily at 2 AM
0 2 * * * /opt/hybrid-infrastructure/pki/scripts/check-certs.sh
```

## Security Best Practices

### Key Security

1. **Root CA Private Key**
   - Store on encrypted USB drive
   - Keep offline except when signing Intermediate CA
   - Use strong passphrase (min 20 characters)
   - Consider hardware security module (HSM)

2. **Intermediate CA Private Key**
   - Encrypt with strong passphrase
   - Restrict file permissions (chmod 400)
   - Regular backups to secure location
   - Monitor access logs

3. **Service Keys**
   - Generate 2048-bit minimum (4096-bit recommended)
   - Never share or reuse keys
   - Rotate regularly (90-day validity enforces this)

### Access Control

```bash
# Set proper permissions
chmod 700 pki/ca/root/private
chmod 700 pki/ca/intermediate/private
chmod 400 pki/ca/root/private/ca.key
chmod 400 pki/ca/intermediate/private/intermediate.key
chmod 400 pki/certs/*//*.key
```

### Backup Strategy

```bash
# Full PKI backup
tar -czf pki-backup-$(date +%Y%m%d).tar.gz \
  --exclude='*.csr' \
  pki/

# Encrypt backup
gpg -c pki-backup-$(date +%Y%m%d).tar.gz

# Store offsite
# - Cloud storage (encrypted)
# - Physical secure location
# - Multiple copies
```

## Troubleshooting

### Common Issues

**"unable to load certificate"**
```bash
# Check file format
file certificate.crt
# Should show: "PEM certificate"

# Verify not corrupted
openssl x509 -in certificate.crt -text -noout
```

**"certificate verify failed"**
```bash
# Check certificate chain
openssl verify -CAfile ca-chain.crt service.crt

# Check dates
openssl x509 -in service.crt -noout -dates
```

**"wrong signature type"**
- Ensure using SHA256 or higher
- Regenerate certificate with correct hash

## Testing

### Test Certificate Chain

```bash
# Test with OpenSSL
openssl s_client -connect localhost:443 \
  -CAfile pki/ca/root/certs/ca.crt

# Should show "Verify return code: 0 (ok)"
```

### Test with curl

```bash
# With custom CA
curl --cacert pki/ca/root/certs/ca.crt https://localhost

# Test certificate validation
curl -v https://localhost
```

## Advanced Topics

### Using Hardware Security Modules (HSM)

For production environments, consider HSM for Root CA:
- FIPS 140-2 Level 3 compliance
- Tamper-resistant key storage
- Examples: YubiHSM, AWS CloudHSM, Azure Key Vault

### Certificate Transparency

Log certificates to public CT logs:
- Improves security visibility
- Required for some browsers
- Use tools like `ct-submit`

### Mutual TLS (mTLS)

Require client certificates:
```nginx
ssl_client_certificate /etc/nginx/certs/ca-chain.crt;
ssl_verify_client on;
```

## Reference

### Key Files

| File | Purpose | Security |
|------|---------|----------|
| ca.key | Root CA private key | Critical - Offline |
| ca.crt | Root CA certificate | Public |
| intermediate.key | Intermediate CA private key | Critical - Encrypted |
| intermediate.crt | Intermediate CA certificate | Public |
| service.key | Service private key | Secret |
| service.crt | Service certificate | Public |
| ca-chain.crt | Full certificate chain | Public |

### Validity Periods

| Certificate | Default Validity | Renewal Threshold |
|-------------|-----------------|-------------------|
| Root CA | 10 years (3650 days) | N/A |
| Intermediate CA | 5 years (1825 days) | 1 year before |
| Service Certs | 90 days | 30 days before |

### Useful Commands

```bash
# Convert formats
openssl x509 -in cert.crt -out cert.pem -outform PEM

# Create PKCS12 bundle
openssl pkcs12 -export -out bundle.p12 \
  -inkey service.key -in service.crt -certfile ca-chain.crt

# Extract from PKCS12
openssl pkcs12 -in bundle.p12 -out cert.pem -nodes
```
