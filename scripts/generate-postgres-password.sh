#!/bin/bash

set -e

echo "=== Generate Secure PostgreSQL Password ==="
echo ""

# Generate a secure random password (44 chars base64 without special chars)
PASSWORD=$(openssl rand -base64 32 | tr -d "=+/")

echo "Generated secure PostgreSQL password:"
echo "" 
echo "Export command:"
echo "export POSTGRES_PASSWORD='$PASSWORD'"
echo ""
echo "Password value (for manual copy):"
echo "$PASSWORD"
echo ""
echo "To use this password, run:"
echo "export POSTGRES_PASSWORD='$PASSWORD'"
echo ""
echo "⚠️  IMPORTANT: Save this password securely!"
echo "   - Store it in your password manager"
echo "   - Add it to your GitHub Secrets as POSTGRES_PASSWORD"
echo "   - Never commit passwords to your repository"