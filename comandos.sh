# =============================================================================
# CUADERNO DE COMANDOS DEL PROYECTO — NO ejecutar este archivo entero.
# =============================================================================
# Registro de todo lo que se ha lanzado a mano, modulo por modulo, para tenerlo
# a mano y no volver a deducirlo. Se copia y se pega linea a linea.
#
# Proyecto:          gcp-data-engineer-muestra
# Region de trabajo: us-east1  (el curso usa us-central1; ver modulo 1, ej. 4)
# VPC:               mi-vpc-curso
#
# Los comandos que CREAN o BORRAN cosas van comentados con "#" delante.
# Descomenta solo el que quieras lanzar. Los de consulta estan sin comentar.
# =============================================================================


# =============================================================================
# MODULO 0 — Entorno local (una sola vez por ordenador)
# =============================================================================

# --- Git y GitHub -----------------------------------------------------------
# git config --global user.name "samahjonathan"
# git config --global user.email "jona.samah@gmail.com"
git config --global --list

# Clave SSH para poder hacer push (la identidad de arriba solo firma, no autentica).
# ssh-keygen -t ed25519 -C "jona.samah@gmail.com"
# eval "$(ssh-agent -s)"
# ssh-add ~/.ssh/id_ed25519
# wl-copy < ~/.ssh/id_ed25519.pub    # copiarla y pegarla en github.com/settings/keys
ssh -T git@github.com                # comprobar: "Hi samahjonathan! ..."

# --- Google Cloud CLI en Fedora ---------------------------------------------
# El repo dice el9 (Enterprise Linux 9) pero funciona en Fedora.
# sudo tee /etc/yum.repos.d/google-cloud-sdk.repo << EOM
# [google-cloud-cli]
# name=Google Cloud CLI
# baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
# enabled=1
# gpgcheck=1
# repo_gpgcheck=0
# gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
# EOM
# sudo dnf install google-cloud-cli
gcloud version

# --- Las DOS autenticaciones, que no son la misma ---------------------------
# gcloud init                            # para el comando gcloud y el proyecto por defecto
# gcloud auth application-default login  # para las LIBRERIAS: Terraform, SDK de Python
#
# Sin la segunda, terraform apply falla aunque gcloud funcione perfectamente.
gcloud config list

# --- Terraform en Fedora ----------------------------------------------------
# sudo dnf install -y dnf-plugins-core
# sudo dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
# sudo dnf install terraform
terraform version

# --- Librerias de Python usadas ---------------------------------------------
# pip install google-cloud-iam        # ejercicio 3, roles personalizados
# pip install google-cloud-compute    # ejercicio 8, snapshots


# =============================================================================
# MODULO 1 — IAM y redes
# =============================================================================

# --- Ejercicio 1: APIs ------------------------------------------------------
# Las APIs se habilitan por Terraform (main.tf, bloque google_project_service),
# no a mano en la consola: asi el entorno es reproducible.
gcloud services list --enabled

# --- Ejercicio 2: cuenta de servicio y rol predefinido ----------------------
# Ver setup-iam/setup-iam.sh. El ID (dev-deployer) es permanente; el
# display-name solo es la etiqueta visible.
# gcloud iam service-accounts create dev-deployer --display-name "Deployer SA"
#
# Un binding responde a QUIEN (--member), QUE (--role) y DONDE (el proyecto).
# "add" es aditivo: respeta los permisos que ya existan.
# gcloud projects add-iam-policy-binding gcp-data-engineer-muestra \
#     --member="serviceAccount:dev-deployer@gcp-data-engineer-muestra.iam.gserviceaccount.com" \
#     --role="roles/compute.viewer"

# Consulta
gcloud iam service-accounts list
gcloud projects get-iam-policy gcp-data-engineer-muestra

# Quitar un binding (mismo formato que add, cambia el verbo)
# gcloud projects remove-iam-policy-binding gcp-data-engineer-muestra \
#     --member="serviceAccount:dev-deployer@gcp-data-engineer-muestra.iam.gserviceaccount.com" \
#     --role="roles/compute.viewer"

# --- Ejercicio 3: rol personalizado (Python) --------------------------------
# python3 setup-iam/custom_role.py
# Salida: Rol creado : projects/gcp-data-engineer-muestra/roles/vmStarterStopper

gcloud iam roles list --project=gcp-data-engineer-muestra          # los personalizados
gcloud iam roles describe vmStarterStopper --project=gcp-data-engineer-muestra
gcloud iam roles describe roles/compute.instanceAdmin.v1           # uno predefinido

# Buscar que rol contiene un permiso concreto
gcloud iam roles list --filter="includedPermissions:compute.instances.create"

# Asignarlo. OJO: los personalizados se referencian con la ruta completa del
# proyecto, no con el prefijo "roles/".
# gcloud projects add-iam-policy-binding gcp-data-engineer-muestra \
#     --member="serviceAccount:dev-deployer@gcp-data-engineer-muestra.iam.gserviceaccount.com" \
#     --role="projects/gcp-data-engineer-muestra/roles/vmStarterStopper"

# Borrar un rol personalizado (queda 7 dias en papelera, se puede recuperar)
# gcloud iam roles delete vmStarterStopper --project=gcp-data-engineer-muestra
# gcloud iam roles undelete vmStarterStopper --project=gcp-data-engineer-muestra

# --- Ejercicio 4: VPC y subredes (Terraform) --------------------------------
# Declaradas en setup-teraform/network.tf. Ver el bloque de Terraform al final.
gcloud compute networks list
gcloud compute networks subnets list --filter="network:mi-vpc-curso"
#
# NOMBRES: minusculas, numeros y guion MEDIO, empezando por letra. Un guion bajo
# ("mi_vpc_curso") lo rechaza el regexp antes de llegar a Google.

# --- Ejercicio 5: firewall y network tags -----------------------------------
# Ver setup-teraform/firewalls-network-tags.sh. Las reglas seleccionan por TAG,
# no por IP: cualquier VM que nazca con el tag hereda el permiso sola.
#
# SSH (puerto 22)
# gcloud compute firewall-rules create allow-ssh-custom \
#     --direction=INGRESS --priority=1000 --network=mi-vpc-curso \
#     --action=ALLOW --rules=tcp:22 --source-ranges=0.0.0.0/0 \
#     --target-tags=web-server
#
# HTTP (puerto 80) — hizo falta anadirla: sin ella el nginx del ej. 6 no
# responde nunca, por bien que haya corrido el startup script.
# gcloud compute firewall-rules create allow-http-custom \
#     --direction=INGRESS --priority=1000 --network=mi-vpc-curso \
#     --action=ALLOW --rules=tcp:80 --source-ranges=0.0.0.0/0 \
#     --target-tags=web-server

gcloud compute firewall-rules list
#
# 0.0.0.0/0 abre a todo internet. Vale para el curso; en real se restringe a la
# IP propia (--source-ranges=TU_IP/32) o al rango de IAP (35.235.240.0/20).


# =============================================================================
# MODULO 2 — Compute Engine
# =============================================================================

# --- Ejercicio 6: VM con nginx ----------------------------------------------
# Ver compute-engine/compute-engine-instance.sh
# Para pasar un ARCHIVO no sirve --metadata (solo acepta valores en linea):
# el flag correcto es --metadata-from-file startup-script=./startup-script.sh
# bash compute-engine/compute-engine-instance.sh

gcloud compute instances list
gcloud compute instances describe servidor-web-1 --zone=us-east1-b
#
# En el bloque "disks" del describe hay DOS nombres: deviceName (como ve el
# disco el SO por dentro) y source (el recurso real en GCP). Para cualquier
# comando de GCP sirve el segundo, el que va tras /disks/.

# Comprobar el servidor web desde fuera (http:// explicito, sin https)
# curl -I http://IP-EXTERNA        # HTTP/1.1 200 OK

# Desde dentro de la VM:
#   sudo -i
#   service nginx status   # active = corriendo ahora
#                          # enabled = arrancara solo al reiniciar (no es lo mismo)

# --- El desvio de region: ZONE_RESOURCE_POOL_EXHAUSTED ----------------------
# us-central1 no tenia capacidad de e2-micro en NINGUNA de sus cuatro zonas.
# No es un error de configuracion: es que Google no tiene maquinas libres de ese
# tipo. e2-micro sigue en capa gratuita en us-east1, asi que se cambio de region
# creando una segunda subred (coste cero).
#
# gcloud compute networks subnets create subred-us-east \
#     --network=mi-vpc-curso --region=us-east1 --range=10.0.2.0/24
#
# El firewall NO hubo que tocarlo: las reglas tienen alcance de VPC, no de
# subred, y seleccionan por tag.
#
# Esa subred se creo a mano y la red la gestiona Terraform -> drift. Se adopto
# con terraform import (ver el bloque de Terraform, mas abajo).

# --- Ejercicio 7: MIG -------------------------------------------------------
# Declarado en setup-teraform/mig.tf (plantilla inmutable + grupo regional).
gcloud compute instance-groups managed list

# --- Ejercicio 8: snapshots -------------------------------------------------
gcloud compute disks list          # el atajo bueno: nombre, zona y tamano de golpe

# cd compute-engine   # hay que lanzarlo DESDE su carpeta, o dar la ruta completa
# python3 backup_vm.py \
#     --project-id gcp-data-engineer-muestra \
#     --disk-name servidor-web-1 \
#     --snapshot-name backup-servidor-web-1 \
#     --zone us-east1-b
#
# Tarda un rato sin imprimir nada: el op.result() espera a que Google termine.

gcloud compute snapshots list      # STATUS READY = la copia termino de verdad

# --- Ejercicio 9: OS Login --------------------------------------------------
# Vincula la cuenta de Google con el usuario de Linux: el acceso pasa a ser una
# consulta a IAM en vez de un archivo de llaves repartido por cada maquina.
# Se pone a nivel de PROYECTO, asi que lo heredan todas las instancias.
# gcloud compute project-info add-metadata --metadata enable-oslogin=TRUE
# gcloud compute ssh servidor-web-1


# =============================================================================
# TERRAFORM — se lanzan desde setup-teraform/
# =============================================================================

# cd setup-teraform

terraform init          # descarga los proveedores; obligatorio la primera vez
terraform fmt           # formato estandar
terraform validate      # sintaxis
terraform plan          # que haria, sin tocar nada. Es de solo lectura, sin riesgo
terraform state list    # que recursos gestiona ya
# terraform apply       # aplicarlo de verdad (pide confirmacion con "yes")

# Adoptar un recurso creado a mano, sin recrearlo. No toca nada en GCP: solo
# escribe en el .tfstate que ese recurso ya es suyo.
# terraform import google_compute_subnetwork.subnet_us_east \
#     projects/gcp-data-engineer-muestra/regions/us-east1/subnetworks/subred-us-east

# Destruir un solo recurso, no todo el proyecto
# terraform destroy -target=google_compute_region_instance_group_manager.mig
#
# validate NO detecta un valor mal escrito en un campo de texto: "us-central"
# en vez de "us-central1" pasa todas las comprobaciones y falla al aplicar.


# =============================================================================
# HIGIENE DE COSTES — al terminar cada sesion
# =============================================================================

# Parar una VM suelta
# gcloud compute instances stop servidor-web-1 --zone=us-east1-b

# Un MIG NO se apaga apagando sus maquinas: el autohealing las repone al instante.
# Hay que bajar su tamano, o destruir el grupo con Terraform.
# gcloud compute instance-groups managed resize app-mig --size=0 --region=us-east1

# Repaso rapido de que hay encendido y que esta ocupando sitio
gcloud compute instances list
gcloud compute instance-groups managed list
gcloud compute disks list
gcloud compute snapshots list
