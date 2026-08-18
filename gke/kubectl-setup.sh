sudo yum install google-cloud-cli-gke-gcloud-auth-plugin # yes
gcloud container clusters get-credentials mi-cluster-gke --zone us-east1-b
sudo yum install kubectl # yes
kubectl get nodes 

