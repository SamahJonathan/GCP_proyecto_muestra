kubectl create deployment nginx-deployment --image=nginx:latest
kubectl expose deployment nginx-deployment --type=LoadBalancer --port 80 --target-port 80
kubectl get services -w
kubectl get pods 

