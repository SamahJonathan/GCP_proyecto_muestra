# Cuaderno de comandos — NO ejecutar este archivo entero.
# Es un registro de lo que se ha lanzado a mano, para tenerlo a mano y no
# volver a deducirlo dentro de tres semanas. Se copia y pega linea a linea.
#
# Proyecto: gcp-data-engineer-muestra
# Region de trabajo: us-east1 (ver docs, ejercicio 4: us-central1 se quedo sin
# capacidad de e2-micro con ZONE_RESOURCE_POOL_EXHAUSTED)


# ---------------------------------------------------------------------------
# Consulta — solo leen, no cambian nada. Son los que mas se repiten.
# ---------------------------------------------------------------------------

# El project-id activo. Evita escribirlo de memoria y equivocarse.
gcloud config get-value project

# Los discos, con su zona y tamano. El atajo bueno para sacar --disk-name y --zone.
gcloud compute disks list

# Las instancias, con su zona, IP y estado (RUNNING / TERMINATED).
gcloud compute instances list

# El detalle completo de una instancia: discos, red, metadata, tags.
# OJO: en el bloque disks, el nombre que sirve es el del final de "source",
# NO el "deviceName" (ese es como ve el disco el sistema operativo por dentro).
gcloud compute instances describe servidor-web-1 --zone=us-east1-b

# Las subredes de la VPC del curso, con su region y rango.
gcloud compute networks subnets list --filter="network:mi-vpc-curso"

# Las reglas de firewall.
gcloud compute firewall-rules list

# Los snapshots. STATUS READY es la confirmacion de que la copia termino.
gcloud compute snapshots list


# ---------------------------------------------------------------------------
# Ejercicio 5 — Firewall
# El comando completo vive en setup-teraform/firewalls-network-tags.sh
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Ejercicio 8 — Snapshot del disco
# ---------------------------------------------------------------------------

# La libreria cliente, sin ella backup_vm.py falla en el import.
pip install google-cloud-compute

# Hay que lanzarlo DESDE esta carpeta, o dar la ruta completa: python3 busca el
# archivo en el directorio donde estas, no en el repositorio entero.
cd ~/Documentos/GCP_proyecto/GCP_proyecto_muestra/compute-engine

python3 backup_vm.py \
    --project-id gcp-data-engineer-muestra \
    --disk-name servidor-web-1 \
    --snapshot-name backup-servidor-web-1 \
    --zone us-east1-b

# Tarda un rato sin imprimir nada: el op.result() del script espera a que Google
# termine. Conviene comprobarlo por fuera con "gcloud compute snapshots list".


# ---------------------------------------------------------------------------
# Terraform — se lanzan desde setup-teraform/
# ---------------------------------------------------------------------------

cd ~/Documentos/GCP_proyecto/GCP_proyecto_muestra/setup-teraform

terraform init          # solo la primera vez, o al anadir un provider
terraform plan          # que va a cambiar, sin tocar nada
terraform apply         # aplicarlo (pide confirmacion con "yes")
terraform state list    # que recursos gestiona ya Terraform

# Adoptar un recurso creado a mano, sin recrearlo (arregla el drift):
# terraform import google_compute_subnetwork.subnet_us_east \
#     projects/gcp-data-engineer-muestra/regions/us-east1/subnetworks/subred-us-east


# ---------------------------------------------------------------------------
# Higiene de costes — al terminar cada sesion
# ---------------------------------------------------------------------------

# Parar una VM suelta.
# gcloud compute instances stop servidor-web-1 --zone=us-east1-b

# Un MIG NO se apaga apagando sus maquinas: el autohealing las repone.
# Se baja su tamano a cero:
# gcloud compute instance-groups managed resize app-mig --size=0 --region=us-east1
