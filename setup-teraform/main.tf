# ---------------------------------------------------------------------------
# Configuración de Terraform
# Declara de qué proveedores depende este código y con qué versiones.
# Terraform los descarga al ejecutar "terraform init" y deja las versiones
# exactas anotadas en .terraform.lock.hcl, para que todo el equipo use las
# mismas.
# ---------------------------------------------------------------------------
terraform {
  required_providers {
    google = {
      # De dónde se descarga el proveedor (registry.terraform.io).
      source = "hashicorp/google"

      # "~> 6.0" acepta cualquier 6.x (6.1, 6.20...) pero nunca saltará a la 7.0,
      # que podría traer cambios incompatibles.
      version = "~> 6.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Proveedor de Google Cloud
# Valores por defecto que heredarán todos los recursos de este directorio,
# para no repetir el proyecto y la región en cada uno.
# Las credenciales NO se ponen aquí: se toman de "gcloud auth application-default login".
# ---------------------------------------------------------------------------
provider "google" {
  # Proyecto de GCP donde se creará todo. Es también donde se factura.
  project = "gcp-data-engineer-muestra"

  # Región por defecto para los recursos regionales (Iowa, EE.UU.).
  region = "us-central1"
}

# ---------------------------------------------------------------------------
# Habilitación de APIs
# En GCP los servicios vienen desactivados por defecto: hay que encenderlos
# antes de poder crear recursos de ese tipo. Este bloque los activa.
# ---------------------------------------------------------------------------
resource "google_project_service" "apis" {
  # for_each crea un recurso independiente por cada elemento de la lista,
  # en vez de escribir tres bloques casi idénticos.
  # toset() elimina duplicados y es lo que for_each espera recibir.
  for_each = toset([
    "compute.googleapis.com",             # Compute Engine: máquinas virtuales, redes, discos
    "container.googleapis.com",           # GKE: clústeres de Kubernetes gestionados
    "cloudresourcemanager.googleapis.com" # Gestión de proyectos, carpetas y permisos IAM
  ])

  # each.key es el elemento actual de la lista en cada iteración.
  service = each.key

  # false = al hacer "terraform destroy" las APIs se quedan activadas.
  # Se pone así a propósito: desactivar una API rompería cualquier otro
  # recurso del proyecto que la esté usando, aunque no lo gestione Terraform.
  disable_on_destroy = false
}
