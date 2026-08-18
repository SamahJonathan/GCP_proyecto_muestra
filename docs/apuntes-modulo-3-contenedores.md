# Apuntes del curso — Módulo 3: Contenedores y serverless

Notas de la transcripción del módulo 3, ejercicios 10 a 13: GKE, objetos de Kubernetes,
Cloud Run y Cloud Functions.

Continúa desde [`apuntes-modulo-2-compute-engine.md`](apuntes-modulo-2-compute-engine.md).
El hilo del curso avanza un escalón: el módulo 2 iba de **máquinas** (tú gestionas el
sistema operativo); este va de **contenedores** (tú entregas la aplicación y la plataforma
se encarga del resto).

> **Cómo leer estos apuntes.** La base es la transcripción del curso; los bloques marcados
> con **🔧** son de la ejecución real en este proyecto y no salen en el vídeo. Los ejercicios
> **10 y 11 ya se hicieron**; el 12 y el 13, todavía no.
>
> Dos cosas cambian respecto del vídeo en todo el módulo: la **región** (el curso usa
> `us-central1` y este proyecto trabaja en **`us-east1`**) y el **coste**, que aquí deja de
> ser cero.

---

## La escalera del módulo

Los cuatro ejercicios son el mismo problema —«tengo un contenedor, quiero que corra»—
resuelto con cuatro niveles de delegación:

| Ejercicio | Servicio | Qué gestionas tú | Qué gestiona Google |
|---|---|---|---|
| 10-11 | GKE Standard | Los nodos, su tamaño y su número | El *control plane* |
| — | GKE Autopilot | Nada de infraestructura | Nodos **y** control plane |
| 12 | Cloud Run | El contenedor | Todo lo demás, y escala a cero |
| 13 | Cloud Functions gen 2 | Una función | Todo, incluido el contenedor |

Merece la pena verlo así desde el principio: no son cuatro servicios competidores, es una
misma escalera con el control en un extremo y la comodidad en el otro.

---

## Ejercicio 10 — Desplegando un clúster GKE con Terraform

### La teoría

**Kubernetes** es *«el sistema operativo de la nube moderna»*, pero instalarlo y mantenerlo
es muy difícil. **GKE** (Google Kubernetes Engine) es la versión gestionada: Google se
encarga del **control plane** —el cerebro del clúster—, lo actualiza y lo repara. Tú solo
gestionas los **node pools**, los servidores donde corren tus aplicaciones.

### Los dos modos, que es la decisión importante

| | **Standard** | **Autopilot** |
|---|---|---|
| Quién elige las máquinas | Tú | Google |
| Qué pagas | Las máquinas, **estén vacías o no** | Solo la CPU y RAM que consumen los pods |
| Precio por unidad | Más barato | Más caro |
| Desperdicio | El tuyo | Eliminado |
| Control | Máximo | Mínimo |

La frase que resume el intercambio: en Standard pagas por *capacidad reservada*, en
Autopilot por *consumo real*. Es más caro por unidad pero no pagas sillas vacías.

El ejercicio usa **Standard**, para ver la configuración de red y permisos.

### La práctica

Partida: en *Kubernetes Engine* no hay ningún clúster. Se crea con Terraform.

Se crea una carpeta `GKE/` con un `gke.tf` y un recurso `google_container_cluster`:

| Campo | Valor del vídeo |
|---|---|
| `name` | `mi-cluster-gke` |
| `location` | `us-central1-a` — una **zona**, así que es un clúster **zonal** |
| `initial_node_count` | El número inicial de nodos |
| `node_config.machine_type` | `e2-medium` — GKE necesita más RAM que la `e2-micro` del módulo 2 |
| `node_config.oauth_scopes` | `cloud-platform`, el ámbito de acceso a las APIs de Google |

> **El archivo acabó mudándose.** En el vídeo se crea primero en su propia carpeta `GKE/`,
> se intenta un `terraform init` allí, y al final se **mueve dentro de `setup-terraform/`**
> y se borra la carpeta suelta. La razón es la que ya se vio en el módulo 2: Terraform
> trabaja por **directorio**, y el estado (`.tfstate`) vive en el directorio donde se lanza.
> Un `.tf` en otra carpeta sería un proyecto de Terraform independiente, con su propio
> estado, que no sabría nada de la red ni de las APIs ya creadas.

```bash
cd setup-terraform
terraform apply
```

Y se repite el patrón conocido: `apply` **refresca primero** todo lo ya provisionado y
después anuncia que solo va a crear lo nuevo. Se confirma con `yes`.

**El clúster tardó 5 minutos y 17 segundos en crearse.** No es un error ni una espera
anormal: levantar un control plane es la operación más lenta que se ha hecho hasta ahora en
el curso.

### `kubectl`: hablar con el clúster

Se crea `GKE/kubectl-setup.sh`. `kubectl` es el comando para comunicarse con **cualquier**
clúster de Kubernetes; `gcloud` sirve para crear el clúster, pero no para operar dentro.

```bash
# Descargar las credenciales del cluster al ~/.kube/config local
gcloud container clusters get-credentials mi-cluster-gke --zone us-central1-a

# Comprobar
kubectl get nodes
```

`get-credentials` es la bisagra entre los dos mundos: le pide a Google los datos de conexión
y los escribe en la configuración local de `kubectl`.

#### Dos plugins que hay que instalar, y el orden importa

El ejercicio se atasca dos veces seguidas por lo mismo — falta software local:

| Síntoma | Qué falta | Solución |
|---|---|---|
| El `get-credentials` avisa de que el plugin no está reconocido | `gke-gcloud-auth-plugin` | `gcloud components install gke-gcloud-auth-plugin` |
| El `kubectl get pods` no funciona | `kubectl` mismo | `gcloud components install kubectl` |

Los dos se instalan con `gcloud components install` y el propio comando lo ofrece: dices que
sí y descarga, instala y hace *postprocessing*. Después hay que **relanzar el
`get-credentials`**.

> **🔧 En Fedora el `gcloud components install` no funciona.** Si el SDK se instaló **por
> repositorio** (`dnf`, que es como se hizo en el módulo 0), el gestor de componentes viene
> **desactivado a propósito**: los paquetes los administra el sistema, no `gcloud`. El propio
> error da el comando equivalente:
>
> | En el vídeo | En este proyecto (Fedora) |
> |---|---|
> | `gcloud components install gke-gcloud-auth-plugin` | `sudo dnf install google-cloud-cli-gke-gcloud-auth-plugin` |
> | `gcloud components install kubectl` | `sudo dnf install kubectl` |
>
> **Ojo con el segundo:** hay dos paquetes que se llaman parecido. El bueno es `kubectl` del
> repositorio **`google-cloud-sdk`**; el `kubernetes1.30-client` de los repos de Fedora es
> otro, con la versión clavada.

> **Por qué existe ese plugin de autenticación.** `kubectl` es una herramienta genérica, no
> sabe nada de Google. El plugin es lo que traduce tu identidad de Google a un token que el
> clúster entiende. Es el mismo patrón que OS Login del ejercicio 9: la autorización la
> sigue decidiendo **IAM**, y el plugin solo es el mensajero.

Con todo instalado:

```bash
kubectl get namespaces   # los espacios lógicos del cluster; salen varios de sistema
kubectl get nodes        # aparece el nodo del cluster creado con Terraform
```

Commit `curso 10`.

### 🔧 Añadido fuera del curso — el clúster acabó en la red `default`

*(2026-08-17. Se detectó al diagnosticar el ejercicio 11.)*

El `gke.tf` no declara `network` ni `subnetwork`, así que **GKE cogió la VPC `default` del
proyecto** — justo la que el módulo 1 decidió no usar. Se ve en dónde viven las reglas que
GKE crea solo:

```
NAME                              NETWORK
gke-mi-cluster-gke-a0dffad7-all   default      <-- no mi-vpc-curso
gke-mi-cluster-gke-a0dffad7-vms   default
k8s-fw-a13d7592a77494dcd8...      default
```

Funciona, pero deja el clúster **fuera de la red que se diseñó**: sus nodos no tienen nada
que ver con `subred-us` ni con `subred-us-east`, y no pueden hablar por IP privada con
`servidor-web-1`. Para que estuviera dentro habría que declararlo:

```hcl
resource "google_container_cluster" "primary" {
    name       = "mi-cluster-gke"
    location   = "us-east1-b"
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet_us_east.id
    ...
}
```

> **Y no se arregla editando el `.tf`.** La red de un clúster es **inmutable**: cambiarla
> obliga a **destruir y recrear** el clúster entero. Es el mismo tipo de campo que el
> `name_prefix` de las instance templates del módulo 2 — hay atributos que no se modifican,
> se reemplazan.

Datos reales del clúster creado: `mi-cluster-gke`, en **`us-east1-b`** (adaptado a la región
de este proyecto, no el `us-central1-a` del vídeo), **1 nodo** `e2-medium`.

> **⚠️ Coste — lo más importante de este ejercicio.** Un clúster de GKE **no es la capa
> gratuita**. Hay dos facturas: la del **control plane** (la capa gratuita cubre un clúster
> zonal al mes por cuenta de facturación) y la de **los nodos**, que se pagan siempre. Una
> `e2-medium` encendida un mes entero son unos 25 USD. Y en modo Standard **se paga aunque
> el clúster esté vacío**, que es justo lo que dice la teoría. Si el clúster se queda
> levantado después del ejercicio, es el recurso más caro de todo el curso.
>
> Para bajarlo: `terraform destroy -target=google_container_cluster.primary`

---

## Ejercicio 11 — `kubectl`, deployments y load balancers

### La teoría: por qué hace falta un *Service*

Dentro de Kubernetes la unidad mínima **no es el contenedor, es el pod**. Un pod puede tener
uno o varios contenedores.

El problema: **los pods son efímeros**. Si un pod muere y renace, su IP interna cambia. No
puedes confiar en ella.

La solución es el objeto **Service**: una **IP estable** más un **balanceador de carga
interno** que reparte el tráfico entre los pods, tengan la IP que tengan.

Y para salir a internet se cambia el **tipo** de servicio a **`LoadBalancer`**, lo que
aprovisiona una IP externa real de Google Cloud.

> Es exactamente el mismo razonamiento que los *network tags* del módulo 1: no apuntes a
> direcciones concretas, apunta a un **rol**, y deja que la plataforma resuelva quién lo
> cumple en cada momento. Los tags seleccionaban máquinas por etiqueta; un Service
> selecciona pods por etiqueta.

### La práctica

Un `GKE/create-service.sh` con tres comandos:

```bash
# 1. Crear el deployment (los pods)
kubectl create deployment nginx-app --image=nginx:latest

# 2. Exponerlo a internet
kubectl expose deployment nginx-app --type=LoadBalancer --port=80

# 3. Ver el resultado
kubectl get services
```

Al hacer el `get services`, la **`EXTERNAL-IP` aparece como `<pending>`**. Es normal: Google
está aprovisionando un balanceador de carga real, y eso tarda. Hay que esperar y repetir el
comando.

Mientras tanto se puede mirar el pod:

```bash
kubectl get pods    # nginx-app ... Running ... 42s
```

Cuando la IP externa aparece, se copia al navegador y sale el **«Welcome to nginx!»**.

Commit `curso 11`.

### 🔧 Lo que se aprendió al ejecutarlo de verdad

**La `EXTERNAL-IP` tardó 49 segundos.** Con `kubectl get services -w` (*watch*) el comando se
queda escuchando e imprime una línea cada vez que algo cambia, así que se ve la transición:

```
nginx-deployment   LoadBalancer   34.118.226.226   <pending>     80:30877/TCP    9s
nginx-deployment   LoadBalancer   34.118.226.226   <pending>     80:30877/TCP   49s
nginx-deployment   LoadBalancer   34.118.226.226   34.23.7.149   80:30877/TCP   49s
```

Tres detalles de esa tabla:

| Qué | Qué significa |
|---|---|
| El servicio `kubernetes` que también aparece | Es el del propio clúster (la API), viene de fábrica y es `ClusterIP` |
| `80:30877/TCP` | **Dos** puertos: el 80 por el que entras tú y el *NodePort* que Kubernetes abre en cada nodo para enrutar hacia los pods. El alto lo asigna él |
| `--target-port 80` | El puerto donde escucha nginx **dentro** del contenedor. Aquí coincide con el de fuera; si la app escuchara en 8080, esa sería la diferencia |

#### GKE crea sus reglas de firewall solo

Contraste con el módulo 1, donde cada regla se escribió a mano: al exponer el service, GKE
creó **dos** reglas automáticamente, y conviene entender el par:

| Regla | Prioridad | Efecto |
|---|---|---|
| `k8s-fw-<hash>` | **999** | Permite `tcp:80` desde `0.0.0.0/0` |
| `k8s-fw-<hash>-deny` | 1000 | Deniega todo lo demás |

Asusta ver un `deny` con `0.0.0.0/0`, pero **el número más bajo gana**: la de permitir tiene
prioridad 999 y va primero. Es el patrón normal de GKE — abrir exactamente el puerto del
service y cerrar el resto.

#### Cuando el navegador da `ERR_TIMED_OUT` y no es culpa de GCP

Pasó, y el diagnóstico completo salió limpio. La secuencia de comprobación, de fuera hacia
dentro, sirve para cualquier service que no responda:

```bash
kubectl get pods -o wide                      # ¿el pod está Running 1/1?
kubectl get endpoints nginx-deployment        # ¿el service apunta a alguna IP de pod?
gcloud compute target-pools get-health <lb> --region=...   # ¿el balanceador ve la instancia HEALTHY?
curl -I http://IP-EXTERNA                     # ¿responde desde fuera del navegador?
```

Todo dio bien —pod `1/1`, endpoint `10.64.0.13:80`, instancia `HEALTHY`, y `curl` devolvió
`HTTP/1.1 200 OK`—, así que el problema estaba **en el navegador**: el mismo forzado a HTTPS
del ejercicio 6, más la caché del intento hecho mientras el balanceador aún se propagaba.

> **La lección de método:** `curl` es el árbitro. Si `curl` responde y el navegador no, deja
> de tocar la infraestructura — el fallo está en tu lado.

#### El orden para bajarlo, que importa

```bash
kubectl delete service nginx-deployment      # PRIMERO: se lleva el balanceador y la IP
kubectl delete deployment nginx-deployment
terraform destroy -target=google_container_cluster.primary
```

Si se destruye el clúster con el `Service` de tipo LoadBalancer todavía vivo, el balanceador
puede quedarse **huérfano** en el proyecto, facturando sin que nada lo reclame. Aparecen
luego con `gcloud compute forwarding-rules list`.

> **La comparación que cierra el círculo.** En el ejercicio 6 conseguir ese mismo *Welcome
> to nginx* costó: crear una VM, escribir un startup script, esperar al `apt-get`, poner un
> network tag y abrir el puerto 80 en el firewall. Aquí son **dos comandos**. Lo que se paga
> a cambio es tener un clúster entero por debajo, con su coste y su complejidad.

---

## Ejercicio 12 — Cloud Run, «la joya de la corona»

### La teoría

La pregunta de partida: *¿y si tengo un contenedor pero no quiero el lío de administrar
Kubernetes?*

**Cloud Run** es *serverless container execution*: le das a Google tu contenedor de Docker y
él te devuelve una **URL HTTPS segura**, con el certificado incluido.

Dos ventajas que lo definen:

- **Scale to zero** — si nadie visita tu web a las 3 de la mañana, Google apaga todas las
  instancias y **no pagas nada**. Cero.
- **Concurrencia** — a diferencia de las funciones antiguas, **una sola instancia de Cloud
  Run atiende hasta 80 peticiones a la vez**.

Es ideal para APIs REST, webs y microservicios **stateless** (sin estado).

### La práctica

Partida: en *Cloud Run → Servicios* no hay nada. Se podría implementar un contenedor,
conectar un repositorio o escribir una función; se hace por comando.

Una carpeta `cloudrun/` con un `cloud-run-deploy.sh`:

```bash
gcloud run deploy mi-servicio-run \
    --image=gcr.io/google-samples/hello-app:1.0 \
    --allow-unauthenticated
```

`--allow-unauthenticated` significa que **no hace falta autenticarse** para acceder: el
servicio es público. Sin ese flag, la URL respondería 403 a cualquiera sin credenciales.

Al lanzarlo, Google avisa de que **la API de Cloud Run no está habilitada** y ofrece
activarla ahí mismo. Se dice que sí, la habilita y despliega.

El comando devuelve **la URL del servicio**. Se abre en el navegador y aparece un *Hello
World* de ejemplo. En la consola quedan además las métricas de observabilidad.

Commit `curso 12`.

> **Ojo con el patrón de las APIs.** Aceptar el «¿la habilito?» del comando es cómodo, pero
> el módulo 2 ya dejó escrito el criterio contrario: si una API hace falta para que el
> entorno funcione, **va al `main.tf`** de Terraform. Si no, el siguiente que clone el repo
> se encontrará con el mismo error y sin saber por qué.

---

## Ejercicio 13 — Cloud Functions gen 2, orientado a eventos

### La teoría

Si Cloud Run es para aplicaciones completas, **Cloud Functions es el pegamento**: fragmentos
pequeños de código que **reaccionan a eventos**.

¿Qué es un evento? Un archivo subido a Storage, un mensaje en Pub/Sub, una llamada HTTP.

El ejemplo que lo explica: quieres que cada vez que alguien suba una imagen a un bucket se
genere una miniatura. **No vas a tener un servidor encendido 24 horas esperando imágenes.**
Usas una función que se despierta, procesa y se vuelve a dormir.

La **generación 2** por debajo **usa Cloud Run**, lo que le da más tiempo de ejecución y más
potencia. Por eso las funciones aparecen ahora dentro de *Cloud Run → Servicios*: los dos
servicios estaban separados y se han unificado.

### La práctica

Dentro de `cloudrun/` se crea una carpeta `funcion-prueba/` con **tres archivos**, que son
el ciclo de vida completo de una función:

| Archivo | Para qué |
|---|---|
| `main.py` | El código |
| `requirements.txt` | Las dependencias de Python |
| `deploy.sh` | El comando de despliegue |

**`main.py`** — importa `functions_framework`, declara que responde a HTTP y devuelve un
saludo:

```python
import functions_framework

@functions_framework.http
def hello_http(request):
    return "Hola desde GCP Cloud Functions"
```

**`requirements.txt`** puede ir vacío en este caso. La regla general es la de siempre en
Python: lo que importes y hayas instalado con `pip install`, si está en el `requirements`,
se despliega solo.

**`deploy.sh`**:

```bash
gcloud functions deploy funcion-prueba \
    --gen2 \
    --runtime=python310 \
    --region=us-central1 \
    --source=. \
    --entry-point=hello_http \
    --trigger-http \
    --allow-unauthenticated
```

Pieza por pieza:

| Flag | Qué hace |
|---|---|
| `--gen2` | La generación nueva: más potencia y más tiempo de ejecución |
| `--runtime` | El intérprete, `python310` |
| `--source=.` | El código está **en el directorio actual** — de ahí el `cd` obligatorio |
| `--entry-point` | **Qué función** de `main.py` se ejecuta: `hello_http` |
| `--trigger-http` | El evento que la despierta |
| `--allow-unauthenticated` | Pública, igual que en Cloud Run |

El `--source=.` obliga a lanzarlo **desde la carpeta de la función**:

```bash
cd cloudrun/funcion-prueba
bash deploy.sh
```

#### El despliegue enciende dos APIs, no una

Al lanzarlo pide habilitar la API de Cloud Functions, y **después pide otra: Cloud Build**.
Eso revela lo que pasa por debajo: Google no ejecuta tu `.py` directamente, sino que
**construye un contenedor con él**. Cloud Build es quien lo compila.

Se puede seguir en la consola de Cloud Build: el *build* tardó **33 segundos y tres pasos**.
Después la función aparece en *Cloud Run → Servicios* con su URL.

#### Editar y volver a desplegar

Desde la consola se puede editar el código, guardar y **volver a implementar**. El ciclo se
ve entero: compila, espera a enrutar el tráfico, termina. Al recargar la URL aparece el
texto nuevo.

Commit del ejercicio. *(En el vídeo se etiqueta `curso 12`, repitiendo el del ejercicio
anterior; debería ser `curso 13`.)*

> **Windows.** El vídeo tiene que quitar las barras de continuación de línea (`\`) para que
> el comando funcione en Windows. En Linux no hace falta: las barras van bien siempre que no
> quede ningún espacio detrás de ellas.

---

## Lo que se lleva del módulo 3

### El hilo: cuánto quieres gestionar

| Ejercicio | Le entregas a Google… | Y él te devuelve… |
|---|---|---|
| 10-11 — GKE | Nodos que tú dimensionas | Un clúster con su control plane gestionado |
| 12 — Cloud Run | Un contenedor | Una URL HTTPS, y escala a cero |
| 13 — Functions | Una función suelta | Lo mismo, y además construye el contenedor por ti |

La pregunta práctica para elegir, que es lo que hay que retener: **¿necesitas orquestar
varios servicios que hablan entre sí, con control fino sobre la infraestructura?** Entonces
GKE. **¿Tienes una app que responde a peticiones HTTP?** Cloud Run. **¿Tienes un trozo de
lógica que reacciona a un evento?** Cloud Functions.

### Lo que aparece por debajo sin que se vea

- Cloud Functions gen 2 **es** Cloud Run por dentro.
- El despliegue de la función usa **Cloud Build** para construir un contenedor.
- El `--type=LoadBalancer` de Kubernetes aprovisiona un **balanceador real de Google Cloud**.

Reconocerlo importa para dos cosas: entender de dónde salen las APIs que hay que habilitar,
y entender de dónde salen las líneas de la factura.

### Las herramientas, y por qué cada una

| Ejercicio | Herramienta | Enfoque |
|---|---|---|
| 10 — Clúster GKE | Terraform | Infraestructura que debe poder recrearse igual |
| 11 — Objetos de Kubernetes | `kubectl` | Se opera **dentro** del clúster; `gcloud` no llega ahí |
| 12 — Cloud Run | `gcloud` | Un despliegue puntual |
| 13 — Function | `gcloud` + código | El código es el artefacto; el comando solo lo sube |

Se mantiene el criterio de los módulos anteriores —**declarativo para la infraestructura,
imperativo para las operaciones**— y aparece una frontera nueva: **`gcloud` crea el clúster,
`kubectl` trabaja dentro de él.** Son dos ámbitos distintos y no se solapan.

### Higiene de costes

Este es el primer módulo que **cuesta dinero de verdad**, y conviene tenerlo presente antes
de empezar:

| Recurso | Qué pasa si se queda encendido |
|---|---|
| Clúster GKE Standard | **Lo más caro del curso.** Los nodos se pagan estén vacíos o no |
| `LoadBalancer` del ejercicio 11 | Un balanceador y una IP externa, ambos con coste |
| Servicio de Cloud Run | **Cero** si nadie lo llama — *scale to zero* |
| Cloud Function | **Cero** en reposo, por la misma razón |

La diferencia entre las dos mitades de esa tabla es el argumento comercial entero del
serverless: en GKE pagas por estar disponible, en Cloud Run pagas por responder.
