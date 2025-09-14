#!/bin/bash

set -e

PROJECT_ID=${GCP_PROJECT_ID:-"vschiavo-home"}

echo "=== Build e Push das Imagens Docker (GCP Container Registry) ==="
echo ""

echo "1. Configurando autenticação do Docker com GCP..."
gcloud auth configure-docker

SHA=$(git rev-parse HEAD)
if [[ -z "$SHA" ]]; then
    echo "❌ Error: Failed to get git commit SHA"
    exit 1
fi
echo "2. SHA do commit atual: $SHA"

echo "3. Construindo imagens Docker..."
echo "   - Construindo client..."
docker build -t "gcr.io/$PROJECT_ID/multi-client:latest" -t "gcr.io/$PROJECT_ID/multi-client:$SHA" -f ./client/Dockerfile ./client

echo "   - Construindo server..."
docker build -t "gcr.io/$PROJECT_ID/multi-server:latest" -t "gcr.io/$PROJECT_ID/multi-server:$SHA" -f ./server/Dockerfile ./server

echo "   - Construindo worker..."
docker build -t "gcr.io/$PROJECT_ID/multi-worker:latest" -t "gcr.io/$PROJECT_ID/multi-worker:$SHA" -f ./worker/Dockerfile ./worker

echo "4. Fazendo push das imagens com tag 'latest'..."
docker push "gcr.io/$PROJECT_ID/multi-client:latest"
docker push "gcr.io/$PROJECT_ID/multi-server:latest"
docker push "gcr.io/$PROJECT_ID/multi-worker:latest"

echo "5. Fazendo push das imagens com tag SHA..."
docker push "gcr.io/$PROJECT_ID/multi-client:$SHA"
docker push "gcr.io/$PROJECT_ID/multi-server:$SHA"
docker push "gcr.io/$PROJECT_ID/multi-worker:$SHA"

echo ""
echo "✅ Build e push concluídos com sucesso!"
echo ""
echo "Imagens publicadas no GCP Container Registry:"
echo "  - gcr.io/$PROJECT_ID/multi-client:latest / gcr.io/$PROJECT_ID/multi-client:$SHA"
echo "  - gcr.io/$PROJECT_ID/multi-server:latest / gcr.io/$PROJECT_ID/multi-server:$SHA"
echo "  - gcr.io/$PROJECT_ID/multi-worker:latest / gcr.io/$PROJECT_ID/multi-worker:$SHA"