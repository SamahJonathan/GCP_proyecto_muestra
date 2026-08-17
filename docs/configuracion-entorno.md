# Configuración del entorno — GCP + Terraform

Notas de la puesta en marcha del proyecto: identidad de Git, acceso a GitHub por SSH,
Google Cloud CLI y los conceptos de Terraform usados en `setup-teraform/main.tf`.

---

## 1. Identidad de Git

Define el nombre y el correo que aparecerán en cada commit. Se configura **una sola vez
por ordenador**, no por proyecto.

```bash
git config --global user.name "samahjonathan"
git config --global user.email "jona.samah@gmail.com"

# Verificar
git config --global --list
```

> El correo debe estar dado de alta en GitHub (**Settings → Emails**). Si no lo está, los
> commits aparecen con ese nombre pero sin enlazar al perfil: sin foto y sin contar en el
> gráfico de contribuciones.

Si prefieres no exponer el correo real, GitHub ofrece uno privado con la forma
`NÚMERO+usuario@users.noreply.github.com`, disponible en esa misma página.

---

## 2. Acceso a GitHub por SSH

La identidad del punto anterior solo firma los commits; **no autentica**. Para hacer `push`
hace falta una clave SSH (o un token). También se configura una sola vez por máquina y
sirve para todos los repositorios de la cuenta.

### Generar la clave

```bash
ssh-keygen -t ed25519 -C "jona.samah@gmail.com"
```

Tres preguntas: ruta (Enter para la de por defecto), passphrase y su confirmación
(Enter para dejarla vacía). Al teclear la passphrase no se ve nada — es normal.

### Cargarla en el agente

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Copiarla y registrarla en GitHub

```bash
cat ~/.ssh/id_ed25519.pub
```

Se pega en **https://github.com/settings/keys → New SSH key**, tipo *Authentication Key*.

> **Importante:** solo se comparte el archivo `.pub`. El archivo `id_ed25519` sin extensión
> es la clave **privada** y nunca debe salir del equipo ni subirse a un repositorio.

### Comprobar

```bash
ssh -T git@github.com
```

Respuesta correcta:

```
Hi samahjonathan! You've successfully authenticated, but GitHub does not provide shell access.
```

Que diga *"does not provide shell access"* es lo esperado: GitHub da acceso a los
repositorios, no a una consola remota.

### Problemas frecuentes al pegar la clave

| Mensaje | Causa | Solución |
|---|---|---|
| `Key is invalid` | Se coló un salto de línea al copiar desde el terminal | Pegar en una sola línea, o usar `wl-copy < ~/.ssh/id_ed25519.pub` |
| `Key is already in use` | Ya está registrada en la cuenta | No hay que hacer nada, pasar a la comprobación |
| Campo *Title* en rojo | El título está vacío | Ponerle cualquier nombre |

---

## 3. Google Cloud CLI en Fedora

### Instalación por repositorio

```bash
sudo tee /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM

sudo dnf install google-cloud-cli
gcloud version
```

El repositorio dice `el9` (Enterprise Linux 9) pero funciona en Fedora: Google no publica
repositorios específicos por versión de Fedora.

### Autenticación

Son dos autenticaciones distintas y suele hacer falta **ambas**:

```bash
# Para el comando gcloud y elegir el proyecto por defecto
gcloud init

# Para que las librerías (Terraform, SDK de Python, Node...) puedan autenticarse en local
gcloud auth application-default login
```

La segunda es la que usa Terraform. Sin ella, `terraform apply` falla aunque `gcloud` funcione.

```bash
# Verificar cuenta y proyecto activos
gcloud config list
```

---

## 4. Terraform

### Instalación en Fedora

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf install terraform
```

### Ciclo de trabajo

```bash
cd setup-teraform

terraform init      # descarga los proveedores (obligatorio la primera vez)
terraform fmt       # aplica el formato estándar
terraform validate  # comprueba la sintaxis
terraform plan      # muestra qué haría, sin tocar nada
terraform apply     # aplica los cambios de verdad
```

`plan` es de solo lectura: se puede ejecutar siempre sin riesgo. Conviene revisarlo antes
de cada `apply`.

---

## 5. Qué son los proveedores

Un **proveedor** es el plugin que le enseña a Terraform a hablar con un servicio concreto.

El núcleo de Terraform solo entiende el lenguaje HCL y lleva la contabilidad de qué existe
(el *estado*). No sabe nada de Google Cloud. Todo el conocimiento específico —qué es una
máquina virtual, qué campos acepta, a qué endpoint de la API llamar— vive en el proveedor.

> **Analogía:** Terraform es el sistema operativo y los proveedores son los drivers. El
> sistema no sabe imprimir; le pide al driver de la impresora que imprima.

### El reparto de tareas en un `apply`

1. Terraform compara lo declarado con el estado guardado
2. Decide qué crear, modificar o destruir
3. **El proveedor** traduce cada acción a llamadas HTTP contra la API de Google
4. Terraform anota el resultado en el estado

### Cómo se reconocen

Todos los recursos de un proveedor llevan su prefijo: `google_compute_instance`,
`google_storage_bucket`, `aws_s3_bucket`, `github_repository`. Ese nombre no lo aporta
Terraform, lo aporta el proveedor.

Se descargan del Terraform Registry (`registry.terraform.io`) a una carpeta oculta
`.terraform/`. Esa carpeta **no se sube a Git**.

### Los dos bloques que se confunden

| Bloque | Responde a |
|---|---|
| `required_providers` | **Qué** proveedor necesito y en qué versión — la declaración de dependencia |
| `provider "google"` | **Cómo** se configura: qué proyecto, qué región, qué credenciales |

Es la diferencia entre poner una librería en `requirements.txt` y pasarle los parámetros
al inicializarla.

Pueden convivir varios proveedores en el mismo proyecto (por ejemplo GCP y GitHub a la vez);
Terraform resuelve las dependencias entre ellos.

---

## 6. El archivo `setup-teraform/main.tf`

### Bloque `terraform`

Declara las dependencias. La restricción de versión:

```hcl
version = "~> 6.0"
```

acepta cualquier `6.x` (6.1, 6.20...) pero nunca salta a la `7.0`, que podría traer cambios
incompatibles. Las versiones exactas quedan fijadas en `.terraform.lock.hcl` para que todo
el equipo use las mismas.

### Bloque `provider`

Valores por defecto heredados por todos los recursos del directorio, para no repetirlos uno
por uno.

> Las credenciales **no** se ponen aquí. Se toman de `gcloud auth application-default login`,
> y así se evita meter secretos en el repositorio.

### Bloque `google_project_service`

En GCP los servicios vienen **desactivados por defecto**. Intentar crear una VM sin haber
activado `compute.googleapis.com` falla. Este bloque los enciende.

Tres construcciones de HCL que aparecen ahí:

- **`for_each`** — genera un recurso independiente por cada elemento de la lista, en lugar
  de escribir tres bloques casi idénticos
- **`toset()`** — convierte la lista en un conjunto sin duplicados, que es el formato que
  `for_each` espera
- **`each.key`** — el elemento de la iteración actual

Y el porqué de `disable_on_destroy = false`: con `true`, un `terraform destroy` apagaría las
APIs y tumbaría cualquier otro recurso del proyecto que dependa de ellas, incluidos los que
no gestiona Terraform.

### APIs habilitadas

| API | Para qué |
|---|---|
| `compute.googleapis.com` | Compute Engine: máquinas virtuales, redes, discos |
| `container.googleapis.com` | GKE: clústeres de Kubernetes gestionados |
| `cloudresourcemanager.googleapis.com` | Gestión de proyectos, carpetas y permisos IAM |

---

## Errores corregidos durante la revisión

| Error original | Corrección | Cómo se detecta |
|---|---|---|
| `container.google.apisd.com` | `container.googleapis.com` | Falla en el `apply`: Google no reconoce el servicio |
| `region = "us-central"` | `region = "us-central1"` | **No lo detecta `validate`** — el proveedor acepta cualquier texto. Falla al crear el primer recurso regional |

El segundo es el peligroso: pasa todas las comprobaciones previas y solo aparece cuando ya
se está aplicando.
