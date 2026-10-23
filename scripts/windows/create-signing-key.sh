#!/usr/bin/env bash
set -euo pipefail
umask 077

root="$(cd "$(dirname "$0")/../.." && pwd)"
output="${1:-$root/.signing/windows}"
if [[ -e "$output" ]]; then
  echo 'Signing directory already exists; refusing to replace a signing identity.' >&2
  exit 1
fi
mkdir -p "$output"
openssl rand -base64 48 > "$output/pfx-password"
openssl req -new -x509 -newkey rsa:3072 -sha256 -days 1825 \
  -subj '/CN=po0-clash self-signed/O=yuuuki-creation' \
  -addext 'basicConstraints=critical,CA:FALSE' \
  -addext 'keyUsage=critical,digitalSignature' \
  -addext 'extendedKeyUsage=codeSigning' \
  -passout "file:$output/pfx-password" \
  -keyout "$output/private-key.pem" -out "$output/certificate.pem"
openssl pkcs12 -export -name po0-clash \
  -in "$output/certificate.pem" -inkey "$output/private-key.pem" \
  -passin "file:$output/pfx-password" -passout fd:3 \
  -out "$output/code-signing.pfx" 3< "$output/pfx-password"
openssl x509 -in "$output/certificate.pem" -outform DER -out "$output/po0-clash-signing.cer"
openssl x509 -in "$output/certificate.pem" -noout -fingerprint -sha256
echo "Signing files saved in $output. Keep the PFX, private key and password private."
