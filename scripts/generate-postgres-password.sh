#!/bin/bash

set -e

echo "=== Generate Secure PostgreSQL Password ==="
echo ""

# Generate a secure random password
PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

echo "Generated secure PostgreSQL password:"
echo "POSTGRES_PASSWORD='$PASSWORD'"
echo ""
echo "To use this password, run:"
echo "export POSTGRES_PASSWORD='$PASSWORD'"
echo ""
echo "⚠️  IMPORTANT: Save this password securely!"
echo "   - Store it in your password manager"
echo "   - Add it to your GitHub Secrets as POSTGRES_PASSWORD"
echo "   - Never commit passwords to your repository"