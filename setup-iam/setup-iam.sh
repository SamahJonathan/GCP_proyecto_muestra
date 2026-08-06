gcloud iam service-accounts create dev-deployer --display-name "Deployer SA"

#Asignar rol (principio de menor privilegio)
gcloud projects add-iam-policy-binding gcp-data-engineer-muestra \
    --member="serviceAccount:dev-deployer@gcp-data-engineer-muestra.iam.gserviceaccount.com" \
    --role="roles/compute.viewer"