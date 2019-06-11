docker build -t vitorspk/multi-client:latest -t vitorspk/multi-client:$SHA -f ./client/Dockerfile ./client
docker build -t vitorspk/multi-server:latest -t vitorspk/multi-server:$SHA -f ./server/Dockerfile ./server
docker build -t vitorspk/multi-worker:latest -t vitorspk/multi-worker:$SHA -f ./worker/Dockerfile ./worker

docker push vitorspk/multi-client:latest
docker push vitorspk/multi-server:latest
docker push vitorspk/multi-worker:latest

docker push vitorspk/multi-client:$SHA
docker push vitorspk/multi-server:$SHA
docker push vitorspk/multi-worker:$SHA

kubectl apply -f k8s
kubectl set image deployments/client-deployment client=vitorspk/multi-client:$SHA
kubectl set image deployments/server-deployment server=vitorspk/multi-server:$SHA
kubectl set image deployments/worker-deployment worker=vitorspk/multi-worker:$SHA