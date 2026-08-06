# Crear una cuenta de servicio: identidad para máquinas (apps, VMs, pipelines),
# para que el código no corra con credenciales personales.
# "dev-deployer" es el ID permanente; "Deployer SA" solo el nombre visible.
# GCP le genera el correo dev-deployer@PROYECTO.iam.gserviceaccount.com
gcloud iam service-accounts create dev-deployer --display-name "Deployer SA"

#Asignar rol (principio de menor privilegio)
# Un binding IAM responde a: QUIÉN (--member) puede hacer QUÉ (--role) y DÓNDE (el proyecto).
# "add" es aditivo: respeta los permisos que ya existan en el proyecto.
gcloud projects add-iam-policy-binding gcp-data-engineer-muestra \
    --member="serviceAccount:dev-deployer@gcp-data-engineer-muestra.iam.gserviceaccount.com" \
    --role="roles/compute.viewer"
