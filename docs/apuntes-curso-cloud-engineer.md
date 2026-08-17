# Apuntes del curso — Google Cloud Engineer desde cero

Notas tomadas de la transcripción del vídeo. Recogen el planteamiento del curso, el setup
inicial (módulo 0) y los cinco ejercicios del módulo 1: IAM y redes.

**Continúa en:** [`apuntes-modulo-2-compute-engine.md`](apuntes-modulo-2-compute-engine.md)
— máquinas virtuales, grupos de instancias, snapshots y OS Login.

Para el detalle técnico de cada ejercicio están los otros dos documentos de esta carpeta:
[`configuracion-entorno.md`](configuracion-entorno.md) y
[`cuentas-de-servicio-iam.md`](cuentas-de-servicio-iam.md). Aquí queda el hilo del curso.

> Los nombres de proyecto que aparecen en el vídeo (`gcp-cloud-engineer-curso-01`) no son los
> de este repositorio, que usa `gcp-data-engineer-muestra`.

---

## Planteamiento del curso

La premisa: querer trabajar como Cloud Engineer sin experiencia que enseñar en las
entrevistas. La respuesta del curso no es teoría, es **portfolio en GitHub**.

Son cinco módulos y en cada uno se repite el mismo ciclo de tres pasos:

1. Explicar la teoría
2. Hacer el ejercicio
3. Subirlo al perfil de GitHub

La idea de fondo es la del argumento comercial: cuando un técnico de selección entra en tu
perfil y ve proyectos reales construidos en Google Cloud, entiende que sabes **construir**
soluciones, no solo estudiarlas.

---

## Módulo 0 — Setup inicial

Cuatro piezas que hay que dejar montadas antes de empezar.

### 1. Cuenta de Google y cuenta de Google Cloud

Se crea un perfil nuevo de Chrome y con él una cuenta de Google (nombre, fecha de
nacimiento, correo nuevo, contraseña y teléfono de confirmación). Después, en
`cloud.google.com` → **Empezar gratis**, se enlaza a Google Cloud rellenando los datos
fiscales y añadiendo una tarjeta.

Sobre el coste, que es la duda habitual:

- **Free tier de 300 $** en crédito.
- **Sin cargos automáticos**: no se pasa a cuenta de pago si tú no lo activas.
- Al terminar cada módulo **se eliminan los proyectos**, para evitar cargos imprevistos.
- Y como red final, se puede **cerrar la cuenta de facturación** desde
  *Billing → Administración de cuentas → Cerrar*. Durante el curso se deja activa.

### 2. Primer proyecto

Se crea un proyecto (`GCP data engineer curso`) y se selecciona. Todo lo que se levante
después vivirá dentro de él.

### 3. GitHub

- Crear el perfil (se puede vincular con *link account* a la cuenta de Google).
- Crear el repositorio del curso, **público**, para que los reclutadores puedan verlo, con
  un README inicial.
- Crear una carpeta local con el mismo nombre y clonar el repositorio ahí desde Visual
  Studio Code (*Clone from GitHub*), abriendo después esa carpeta como workspace.

**Prueba de que el circuito funciona:** se crea un archivo cualquiera (`init.py`, con el
contenido comentado para que no dé errores), se escribe un mensaje de commit y se comitea.

El primer commit **falla**, y el fallo es didáctico: no están configurados el nombre y el
correo de Git. El propio log del error (*Output → Git Log*) dice qué falta y cómo se añade:

```bash
git config --global user.name "TU NOMBRE"
git config --global user.email "TU EMAIL"
```

Con eso configurado se vuelve a subir, se autentica y el archivo aparece en GitHub al
refrescar.

### 4. Google Cloud SDK (`gcloud` CLI)

Se descarga el instalador desde la documentación de Google Cloud —en el vídeo se hace en
Windows por ser lo más transversal— y al terminar se marca la opción de configurar
credenciales.

```bash
gcloud init
```

Esto abre el navegador, se elige la cuenta de Google y queda la línea de comandos
autenticada. A partir de ahí ya se pueden automatizar tareas: levantar instancias, crear
buckets, subir archivos.

---

## Módulo 1 — Configuración de IAM y redes

### Ejercicio 1 — Jerarquía de recursos y APIs

#### La teoría: el árbol de recursos

Todo en Google Cloud empieza por la jerarquía de recursos, que funciona como un árbol:

| Nivel | Qué es | Para qué sirve |
|---|---|---|
| **Organización** | La raíz — tu empresa | Políticas globales |
| **Carpetas** (*folders*) | Las ramas | Agrupar por departamento (RRHH, ventas, marketing) o por entorno (desarrollo, staging, producción) |
| **Proyectos** | Las hojas — la unidad base | Contienen los recursos |

Dos consecuencias que conviene fijar:

- Todos los recursos (VMs, contenedores, data lakes, data warehouses) **pertenecen a
  proyectos, no a usuarios**.
- La **facturación se configura a nivel de proyecto**.

#### Las APIs vienen desactivadas

Un proyecto recién creado es *como una caja fuerte*: no puedes levantar máquinas virtuales
ni clústeres de Kubernetes hasta habilitar las APIs correspondientes —por ejemplo
`compute.googleapis.com` para Compute Engine.

Es así por dos razones: **seguridad** y no saturar la interfaz con servicios que no usas.

#### La práctica

Se crea el proyecto `gcp-cloud-engineer-curso-01` y, como primer entregable, un
`setup-terraform/main.tf` que habilita las APIs de forma **programática y reproducible**,
con `provider "google"` (project ID y región) y los bloques `google_project_service`.

Autenticación necesaria antes de nada:

```bash
gcloud auth application-default login
```

Es la que usan las librerías y Terraform, distinta de `gcloud init`. Después:

```bash
terraform init
terraform apply
```

Detalles del recorrido, que son los que se aprenden de verdad:

- **Terraform no estaba instalado.** El asistente lo detecta al fallar el `init` y propone
  instalarlo (`winget`/`choco` en Windows).
- **Error de sintaxis en el `main.tf`**: faltaba un salto de línea. Se identifica pasándole
  el error al asistente.
- `apply` lista las APIs que va a habilitar y pide confirmación (`yes`).
- **Habilitar una API tarda unos minutos.** Hay que tener paciencia: en la biblioteca de
  APIs sigue apareciendo *Habilitar* hasta que termina. Al refrescar ya sale habilitada.

Y `disable_on_destroy = false`, para que un `destroy` no apague las APIs y tumbe otros
recursos del proyecto.

---

### Ejercicio 2 — Cuentas de servicio e IAM

#### La teoría

**IAM** = *Identity and Access Management*. Gestiona dos cosas:

- **El quién** — los usuarios que acceden. Pueden ser personas o **cuentas de servicio**.
- **El qué** — los servicios a los que pueden acceder.

Una cuenta de servicio es especial: es una **identidad para tus aplicaciones**, pero
también es **un recurso** en sí misma.

**El concepto vital: principio de menor privilegio.** Si tienes un script que solo necesita
subir archivos a un bucket, jamás le des `owner` ni `editor`. Si esa cuenta se ve
comprometida, quien la tenga *tiene las llaves de todo el árbol*.

Y un detalle que sorprende: **los permisos en GCP son aditivos**. Si te doy lectura en la
organización y escritura en el proyecto, acabas con los dos a la vez.

#### La práctica

Un `setup-iam/setup-iam.sh` con dos comandos de `gcloud`:

1. **Crear** la cuenta de servicio `dev-deployer`, con display name `Deployer SA`.
2. **Vincularla** al proyecto con el rol `roles/compute.viewer` —solo ver los recursos de
   Compute Engine que se levanten.

Antes hay que autenticarse dos veces, como en el ejercicio anterior:

```bash
gcloud init                            # cuenta y proyecto por defecto
gcloud auth application-default login  # credenciales para las librerías
```

Comprobaciones que se van haciendo en la consola:

- Antes de lanzar el script, en *IAM → Cuentas de servicio* solo aparece la que creó
  automáticamente la API de Compute del ejercicio 1.
- Tras el `create`, la cuenta ya está listada, **pero no aparece en IAM**: todavía no tiene
  ningún permiso.
- Tras el binding, en IAM sale con el rol *Visualizador de Compute*.

> El comando del binding hay que **pegarlo en una sola línea** si las continuaciones (`\`)
> se rompen al copiar.

Después, desde la consola, se ve que se pueden ir **añadiendo más roles** a la misma
cuenta (visualizador de buckets de Storage, visualizador de objetos, visualizador de
Compute...) y que se acumulan. Eso es la aditividad de la que hablaba la teoría.

Por último, commit `curso 2`, sincronizar, y el script ya está visible en el repositorio
público.

---

### Ejercicio 3 — Roles personalizados

#### La teoría: los tres tipos de rol

| Tipo | Ejemplos | Cuándo usarlos |
|---|---|---|
| **Primitivos / básicos** | `owner`, `editor`, `viewer` | De la vieja escuela. **Evitarlos en producción** siempre que se pueda |
| **Predefinidos** | `compute.admin`, `storage.objectViewer` | Los desarrolla y autogestiona Google. Son los más utilizados |
| **Personalizados** (*custom roles*) | los que definas tú | Cuando el predefinido es demasiado amplio |

**El caso que justifica un rol personalizado**, tal cual lo plantea el vídeo: imagina una
auditoría de seguridad. Necesitas que un operador pueda **detener** una máquina virtual que
se ha vuelto loca, pero que **no pueda borrarla ni ver su contenido**. No existe un rol de
Google para eso. Hay que construirlo combinando permisos individuales, como
`compute.instances.stop`.

Es *cirugía muy fina*: un rol que solo permite un par de acciones concretas.

#### La práctica

En la consola, *IAM → Roles* muestra que todos son de tipo **predefinido**; de
personalizados solo hay uno y está en estado *borrado* (ver la nota sobre el borrado de 7
días en [`cuentas-de-servicio-iam.md`](cuentas-de-servicio-iam.md)).

Se crea `setup-iam/custom_role.py` con la librería `google-cloud-iam` (`iam_admin_v1`), que
define un rol **VM Starter Stopper** con los permisos de iniciar y parar instancias.

```bash
pip install google-cloud-iam
python3 custom_role.py
```

Dos tropiezos del recorrido:

- **El script no hacía nada.** Le faltaba el bloque `if __name__ == "__main__":`, así que no
  llegaba a ejecutar la función.
- **Los valores estaban hardcodeados.** Se refactoriza con `argparse` para pasar
  `--project-id` y `--role-id` por línea de comandos. A partir de ahí, `--help` documenta
  el uso y ejecutarlo sin argumentos avisa de lo que falta.

Con el rol creado, en *IAM → Roles* aparece como **personalizado** y **habilitado**. Se le
asigna a la cuenta de servicio del ejercicio anterior de dos formas equivalentes:

- Por consola: editar la cuenta → *Agregar otro rol* → buscarlo por nombre.
- Por CLI: el mismo `add-iam-policy-binding` de antes, pero con la **ruta completa** del
  rol, porque es de proyecto:

```
--role="projects/ID-DEL-PROYECTO/roles/vmStarterStopper"
```

Commit `curso 3` y el código del rol personalizado queda en el portfolio.

---

### Ejercicio 4 — VPCs y el mito del *auto mode*

#### La teoría: global pero por regiones

La **VPC** (*Virtual Private Cloud*) es la red privada **global**. Y global de verdad: una
sola VPC puede abarcar Londres, China y Estados Unidos.

Las **subredes**, en cambio, son **regionales**. Esa asimetría es la clave del modelo de red
de GCP.

#### El problema de la red `default`

Cuando creas un proyecto, Google te da una red `default` en **auto mode**, que crea
automáticamente **una subred en cada región del mundo**. Suena cómodo y es un problema doble:

- **Riesgo de seguridad** — superficie de red que no has pedido ni revisado.
- **Desastre de gestión de IPs** en entornos corporativos — rangos asignados sin criterio,
  que luego chocan con otras redes.

La solución idónea casi siempre es el **custom mode**: el ingeniero define
**explícitamente** qué rangos de IP se usan y en qué regiones. Nada aparece por defecto.

#### La práctica

Partida: en *Redes VPC* la única red del proyecto es la `default` y todas sus subredes son
las automáticas. Se podría crear la red desde la consola, pero se hace con Terraform.

Un `setup-terraform/network.tf` con dos recursos:

| Recurso | Qué define |
|---|---|
| `google_compute_network` | La VPC del curso, con **`auto_create_subnetworks = false`** |
| `google_compute_subnetwork` | Una subred en `us-central1`, con su rango de IPs, dentro de esa red |

`auto_create_subnetworks = false` **es** el custom mode: es la línea que impide que se
repita el comportamiento de la `default`.

```bash
cd setup-terraform
terraform apply
```

> En este repositorio la carpeta está creada como **`setup-teraform`** (le falta una `r`).
> No afecta a nada —Terraform trabaja sobre el directorio en el que se lanza—, pero es el
> nombre que hay que teclear al hacer `cd`.

#### Dos tropiezos antes de que el `apply` llegue a proponer nada

El primer `apply` no mostró plan: falló en la **validación**, antes de hablar con Google.

```
Error: "name" ("mi_vpc_curso") doesn't match regexp
"^(?:[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?)$"

  with google_compute_network.vpc_network,
  on network.tf line 2
```

| Síntoma | Causa | Arreglo |
|---|---|---|
| El `name` no pasa el regexp | La VPC se llamó `mi_vpc_curso`, con **guion bajo** | `mi-vpc-curso`, con guion medio |
| (se veía después) La subred no se crea | El CIDR estaba escrito `10.0,1.0/24`, con **coma** | `10.0.1.0/24` |

**La regla que hay que interiorizar:** los nombres de recursos de GCP —redes, subredes, VMs,
discos, reglas de firewall— admiten solo **minúsculas, números y `-`**, tienen que **empezar
por letra** y como mucho 63 caracteres. Eso es literalmente lo que dice el regexp del error.

> **De dónde viene la confusión.** En `resource "google_compute_network" "vpc_network"` hay
> **dos** nombres, y solo uno viaja a Google:
>
> | Nombre | Dónde vive | Guion bajo |
> |---|---|---|
> | `"vpc_network"` — la etiqueta de Terraform | Solo dentro del `.tf`, para referenciarlo (`google_compute_network.vpc_network.id`) | **Sí**, es la convención |
> | `name = "mi-vpc-curso"` | El nombre real del recurso **en GCP** | **No** |
>
> Es fácil copiar el estilo del de la izquierda al de la derecha. Por eso el ejercicio 5
> apunta a `--network=mi-vpc-curso`: ese es el nombre que existe de verdad.

El fallo del CIDR merece una nota aparte porque **no lo detectó esta pasada**: Terraform
valida los recursos en orden y se paró en el primero, así que la coma de `10.0,1.0/24` habría
salido en el siguiente `apply`. Cuando un `apply` falla en validación, conviene **releer el
archivo entero** en vez de arreglar solo lo que aparece en pantalla.

Con las dos correcciones hechas:

El plan anuncia dos recursos —la network y la subnetwork—, se confirma con `yes` y la
creación de la red tarda un rato (`Still creating...`). Al refrescar la consola aparece la
nueva VPC con **una única subred**, en `us-central1` y con el rango indicado en el `.tf`.

Que la red existe de verdad se confirma solo en el ejercicio siguiente: el
`firewall-rules create --network=mi-vpc-curso` habría fallado con *network not found* si el
`apply` no hubiera terminado bien.

Commit `curso 04`. En GitHub, el `network.tf` queda dentro de `setup-terraform`.

> **Detalle a tener en cuenta:** la teoría plantea *borrar la red `default`* y diseñar desde
> cero. En la práctica del vídeo la `default` se deja donde está y solo se **añade** la VPC
> personalizada. Para que el ejercicio cumpla lo que promete la teoría, faltaría eliminarla:
> `gcloud compute networks delete default` (con cuidado: se lleva por delante sus subredes y
> sus reglas de firewall).

---

### Ejercicio 5 — Firewall *stateful* y network tags

#### La teoría: qué significa *stateful*

El firewall de Google es **stateful**: si permites una conexión de entrada (*ingress*), la
respuesta de salida (*egress*) se permite **automáticamente**. No hay que abrir puertos en
ambas direcciones.

Y el punto de partida: **por defecto todo el tráfico entrante está bloqueado**. El trabajo
consiste en abrir los agujeros necesarios, uno a uno y justificados.

#### El problema clásico, y los network tags

Tienes 100 servidores web y 50 bases de datos. ¿Escribes 150 reglas, una por IP? No.

Para eso existen los **network tags**. Etiquetas las máquinas (`web-server`, `db-server`) y
la regla dice *«abre el puerto 80 a cualquier máquina con la etiqueta `web-server`»*.

La ventaja es la que hace que esto escale: si mañana creas diez máquinas nuevas con esa
etiqueta, **la regla se les aplica por sí misma**. La regla apunta a un rol, no a un
inventario.

Los tags se pueden poner en los servicios que se levanten en Google Cloud —Compute Engine,
App Engine...— que se verán en ejercicios siguientes.

#### La práctica

Partida: buscando *firewall* en la consola aparecen cuatro reglas, todas con el prefijo
`default-`, porque son las que crea GCP automáticamente.

Se crea un `firewalls-network-tags.sh` con un solo comando de `gcloud`, apuntando a la VPC
del ejercicio anterior. **En este repositorio el archivo quedó dentro de
`setup-teraform/`**, no en `setup-iam/` como sugiere el vídeo:

```bash
gcloud compute firewall-rules create allow-ssh-custom \
    --direction=INGRESS \
    --priority=1000 \
    --network=mi-vpc-curso \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=web-server
```

Pieza por pieza:

| Parámetro | Qué hace |
|---|---|
| `allow-ssh-custom` | El nombre de la regla, que es lo que se verá en la consola |
| `--direction=INGRESS` | Tráfico entrante |
| `--priority=1000` | Se pone explícito, aunque es el valor por defecto. Número **más bajo = más prioritaria** |
| `--network` | La VPC creada en el ejercicio 4 — no la `default` |
| `--action=ALLOW` | Permitir (la alternativa es `DENY`) |
| `--rules=tcp:22` | Protocolo TCP, puerto 22: **SSH** |
| `--source-ranges=0.0.0.0/0` | Desde qué IPs de origen se permite — aquí, **desde cualquiera** |
| `--target-tags=web-server` | **A qué máquinas se aplica** — la clave del ejercicio |

Se lanza en una sola línea si las continuaciones se rompen al copiar. La ejecución funcionó
a la primera:

```
Creating firewall...⠹Created [https://www.googleapis.com/compute/v1/projects/
gcp-data-engineer-muestra/global/firewalls/allow-ssh-custom].
Creating firewall...done.
NAME              NETWORK       DIRECTION  PRIORITY  ALLOW   DENY  DISABLED
allow-ssh-custom  mi-vpc-curso  INGRESS    1000      tcp:22        False
```

Vale la pena leer esa tabla de salida entera, porque confirma las cuatro cosas que se
querían: la regla está en `mi-vpc-curso` **y no en la `default`**, es de entrada, tiene
prioridad 1000 y abre `tcp:22`. `DISABLED False` significa que está activa.

Al refrescar la consola aparece la regla nueva junto a las `default-`, con `web-server` como
destino.

> **`--source-ranges=0.0.0.0/0` deja el puerto 22 abierto a todo Internet.** Para un
> laboratorio del curso vale, pero es justo lo que no se hace en un entorno real: ahí se
> restringe al rango de la oficina/VPN, o directamente se usa **IAP TCP forwarding**
> (`35.235.240.0/20`) para no exponer SSH a la red pública. El ejercicio 9 del módulo 2
> ataca el otro lado del mismo problema —**quién** puede entrar— con OS Login.

Commit `curso 05` y sincronizar.

> Lo importante de este ejercicio es que la regla ya existe **antes** de que exista ninguna
> máquina. No hay nada que tenga la etiqueta `web-server` todavía: el permiso está definido
> y esperando, y se activará solo en cuanto se levante una VM con ese tag.

---

## Lo que se lleva de aquí

**Las tres autenticaciones distintas**, que es el enredo más común al empezar:

| Comando | Para qué |
|---|---|
| `git config --global user.name/email` | Firmar los commits |
| `gcloud init` | Autenticar el comando `gcloud` y fijar el proyecto por defecto |
| `gcloud auth application-default login` | Que las **librerías** (Terraform, SDK de Python) puedan autenticarse en local |

**Las herramientas del módulo, y por qué cada una:**

| Ejercicio | Herramienta | Enfoque |
|---|---|---|
| 1 — APIs | Terraform | Declarativo, reproducible, con estado |
| 2 — Cuentas de servicio | `gcloud` en Bash | Imperativo, rápido para operaciones puntuales |
| 3 — Rol personalizado | Python + SDK | Cuando hace falta lógica o parámetros |
| 4 — VPC y subred | Terraform | Infraestructura que hay que poder recrear igual |
| 5 — Regla de firewall | `gcloud` en Bash | Un ajuste puntual sobre lo ya creado |

**Y el hilo conceptual, de principio a fin:** todo vive en un proyecto → el proyecto nace
cerrado y hay que abrir sus APIs → las aplicaciones necesitan su propia identidad → esa
identidad recibe el mínimo permiso posible → y si el mínimo no existe, se fabrica → la red
también se define a mano en lugar de aceptar la que viene → y el acceso se abre por
**etiqueta**, no por IP.

Al final es el mismo criterio repetido en cinco capas: **nada por defecto**. Ni las APIs, ni
los permisos, ni las subredes, ni los puertos.

**Dos patrones que se repiten y conviene reconocer:**

- **Lo declarativo para la infraestructura, lo imperativo para las operaciones.** Terraform
  para lo que debe poder recrearse idéntico (APIs, red); `gcloud` para acciones sueltas
  sobre lo que ya existe (un binding, una regla).
- **Apuntar a roles, no a instancias.** La cuenta de servicio no es «mi script», es «quien
  despliega»; el network tag no es «esta IP», es «los servidores web». Ambas ideas hacen que
  la configuración siga siendo válida cuando cambien las piezas concretas.
