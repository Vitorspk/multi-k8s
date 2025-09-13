#!/bin/bash

set -e

echo "=== Multi-K8s Environment Variables Setup ==="
echo ""
echo "This script will help you configure the required environment variables"
echo "for deploying the multi-k8s application to GCP."
echo ""

ENV_FILE=".env.local"

# Check if .env.local exists and backup if needed
if [[ -f "$ENV_FILE" ]]; then
    echo "⚠️  $ENV_FILE already exists, creating backup..."
    cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    > "$ENV_FILE"  # Clear the file
fi

echo "Creating environment variables file: $ENV_FILE"
echo ""

# GCP Project ID
if [[ -z "${GCP_PROJECT_ID}" ]]; then
    read -p "Enter your GCP Project ID: " GCP_PROJECT_ID
    echo "export GCP_PROJECT_ID='$GCP_PROJECT_ID'" >> $ENV_FILE
else
    echo "✅ GCP_PROJECT_ID already set: $GCP_PROJECT_ID"
fi

# GCP Region
if [[ -z "${GCP_REGION}" ]]; then
    read -p "Enter your GCP Region (default: southamerica-east1): " GCP_REGION
    GCP_REGION=${GCP_REGION:-southamerica-east1}
    echo "export GCP_REGION='$GCP_REGION'" >> $ENV_FILE
else
    echo "✅ GCP_REGION already set: $GCP_REGION"
fi

# PostgreSQL Password
if [[ -z "${POSTGRES_PASSWORD}" ]]; then
    echo ""
    echo "PostgreSQL password options:"
    echo "1) Generate a secure random password"
    echo "2) Enter your own password"
    echo ""
    read -p "Choose option (1 or 2): " PASSWORD_OPTION
    
    if [[ "$PASSWORD_OPTION" == "1" ]]; then
        POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/")
        echo "Generated secure password (saved to $ENV_FILE)"
        echo "export POSTGRES_PASSWORD='$POSTGRES_PASSWORD'" >> $ENV_FILE
    else
        read -sp "Enter PostgreSQL password: " POSTGRES_PASSWORD
        echo ""
        echo "export POSTGRES_PASSWORD='$POSTGRES_PASSWORD'" >> $ENV_FILE
    fi
else
    echo "✅ POSTGRES_PASSWORD already set"
fi

# Docker Hub credentials
if [[ -z "${DOCKER_USERNAME}" ]]; then
    read -p "Enter your Docker Hub username: " DOCKER_USERNAME
    echo "export DOCKER_USERNAME='$DOCKER_USERNAME'" >> $ENV_FILE
else
    echo "✅ DOCKER_USERNAME already set: $DOCKER_USERNAME"
fi

if [[ -z "${DOCKER_PASSWORD}" ]]; then
    read -sp "Enter your Docker Hub password/token: " DOCKER_PASSWORD
    echo ""
    echo "export DOCKER_PASSWORD='$DOCKER_PASSWORD'" >> $ENV_FILE
else
    echo "✅ DOCKER_PASSWORD already set"
fi

echo ""
echo "✅ Environment variables configured!"
echo ""
echo "To use these variables, run:"
echo "source $ENV_FILE"
echo ""
echo "⚠️  SECURITY NOTES:"
echo "   - $ENV_FILE contains sensitive credentials"
echo "   - It's already added to .gitignore"
echo "   - Never commit credential files to your repository"
echo "   - For GitHub Actions, add these as repository secrets:"
echo "     * GCP_SA_KEY (service account JSON content)"
echo "     * DOCKER_USERNAME"
echo "     * DOCKER_PASSWORD"
echo "     * POSTGRES_PASSWORD"