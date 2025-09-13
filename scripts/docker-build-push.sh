#!/bin/bash

set -e

DOCKER_USERNAME=${DOCKER_USERNAME:-""}
DOCKER_PASSWORD=${DOCKER_PASSWORD:-""}

echo "=== Build e Push das Imagens Docker ==="
echo ""

if [ -z "$DOCKER_USERNAME" ]; then
    read -p "Digite seu Docker Hub username: " DOCKER_USERNAME
fi

if [ -z "$DOCKER_PASSWORD" ]; then
    read -sp "Digite sua Docker Hub password: " DOCKER_PASSWORD
    echo ""
fi

echo "1. Fazendo login no Docker Hub..."
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

SHA=$(git rev-parse HEAD)
if [[ -z "$SHA" ]]; then
    echo "❌ Error: Failed to get git commit SHA"
    exit 1
fi
echo "2. SHA do commit atual: $SHA"

echo "3. Construindo imagens Docker..."
echo "   - Construindo client..."
docker build -t "$DOCKER_USERNAME/multi-client:latest" -t "$DOCKER_USERNAME/multi-client:$SHA" -f ./client/Dockerfile ./client

echo "   - Construindo server..."
docker build -t "$DOCKER_USERNAME/multi-server:latest" -t "$DOCKER_USERNAME/multi-server:$SHA" -f ./server/Dockerfile ./server

echo "   - Construindo worker..."
docker build -t "$DOCKER_USERNAME/multi-worker:latest" -t "$DOCKER_USERNAME/multi-worker:$SHA" -f ./worker/Dockerfile ./worker

echo "4. Fazendo push das imagens com tag 'latest'..."
docker push "$DOCKER_USERNAME/multi-client:latest"
docker push "$DOCKER_USERNAME/multi-server:latest"
docker push "$DOCKER_USERNAME/multi-worker:latest"

echo "5. Fazendo push das imagens com tag SHA..."
docker push "$DOCKER_USERNAME/multi-client:$SHA"
docker push "$DOCKER_USERNAME/multi-server:$SHA"
docker push "$DOCKER_USERNAME/multi-worker:$SHA"

echo ""
echo "✅ Build e push concluídos com sucesso!"
echo ""
echo "Imagens publicadas:"
echo "  - $DOCKER_USERNAME/multi-client:latest / $DOCKER_USERNAME/multi-client:$SHA"
echo "  - $DOCKER_USERNAME/multi-server:latest / $DOCKER_USERNAME/multi-server:$SHA"
echo "  - $DOCKER_USERNAME/multi-worker:latest / $DOCKER_USERNAME/multi-worker:$SHA"