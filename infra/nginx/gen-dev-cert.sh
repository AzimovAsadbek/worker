#!/bin/sh
# Self-signed certificate for local HTTPS testing only. In production mount real certificates
# (e.g. Let's Encrypt) as infra/nginx/certs/fullchain.pem and privkey.pem.
set -e
cd "$(dirname "$0")/certs"
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout privkey.pem -out fullchain.pem \
  -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null
echo "Dev certificate written to infra/nginx/certs/"
