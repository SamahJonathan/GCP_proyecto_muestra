# Apuntes del curso — Módulo 2: Compute Engine

Notas de la transcripción del módulo 2, ejercicios 6 a 9: máquinas virtuales, grupos de
instancias gestionados, snapshots de disco y OS Login.

Continúa desde [`apuntes-curso-cloud-engineer.md`](apuntes-curso-cloud-engineer.md)
(módulo 0 y módulo 1: IAM y redes). Este módulo **se apoya directamente** en lo que se creó
allí: la subred del ejercicio 4 y el network tag del ejercicio 5 reaparecen en cuanto se
levanta la primera máquina.

---

## Ejercicio 6 — Máquinas virtuales, zonas y *bootstrapping*

### La teoría

**Compute Engine** son las máquinas virtuales de toda la vida: eliges CPU, RAM y sistema
operativo.

Lo crucial aquí es la **disponibilidad**. Una VM es un recurso **zonal**: si la zona
`us-central1-a` se incendia, tu máquina desaparece. La solución son los grupos de instancias
—que es justo el ejercicio siguiente—, pero primero conviene entender una máquina sola.

### Cómo se configura el software de dentro

La pregunta importante del ejercicio: ¿cómo instalas lo que la máquina tiene que ejecutar?

> Entrando por SSH e instalando a mano: **jamás**. Eso no es escalable.

Se usan **startup scripts**: scripts en Bash o Python que se pegan en la **metadata** de la
máquina. Cuando arranca por primera vez, el agente de Google los ejecuta **con permisos de
root**. Es la base de la automatización.

El objetivo de la práctica, dicho de forma bonita: *provisionar un servidor web que se
autoconfigura nada más nacer*.

### La práctica

Partida: en *Compute Engine → Instancias de VM* no hay ninguna máquina. Se podría crear
desde la consola, pero se hace por línea de comandos.

Un `compute-engine-create-instance.sh` con `gcloud compute instances create`:

| Parámetro | Valor y por qué |
|---|---|
| nombre | `servidor-web-1` |
| `--zone` | `us-central1-a` — recuerda: la VM vive en **una** zona |
| `--machine-type` | `e2-micro`, muy poco potente, pero para un servidor web de prueba sobra |
| `--subnet` | **la subred creada en el ejercicio 4** — no la `default` |
| `--tags` | `web-server` — **el mismo tag de la regla de firewall del ejercicio 5** |
| `--metadata-startup-script` | Instalar nginx y arrancar el servicio |

Esas dos filas del medio son el momento en que el módulo 1 empieza a rendir: la máquina nace
dentro de la red que diseñaste y hereda el permiso de SSH **por llevar la etiqueta**, sin
tocar el firewall.

Igual que en otros ejercicios, hay que dejar el comando en **una sola línea** sustituyendo
los saltos por espacios.

#### Sacar el script a un archivo aparte

En vez de dejar el startup script incrustado en el comando, se extrae a su propio
`startup-script.sh` y se referencia desde el comando. Es más limpio y el script queda
versionado por separado en el repositorio.

> **Ojo con el flag.** Para pasar un **archivo** no sirve `--metadata`, que solo acepta
> valores en línea. El correcto es:
>
> ```bash
> --metadata-from-file startup-script=./startup-script.sh
> ```

#### Comprobar que funciona

La salida del comando confirma que la máquina está creada y en estado `RUNNING`, y da las
IPs. **Hay que quedarse con la IP externa**: es la que permite abrir el servidor web.

En la consola aparece ya el servidor, con su zona, su IP, la etiqueta `web-server`, su
almacenamiento y la red —que es la que se creó en el módulo anterior.

Para verlo en el navegador:

```
http://IP-EXTERNA
```

> Escribe **`http://` explícitamente** y sin `https`. Es un detalle tonto que hace perder
> tiempo: nginx recién instalado no tiene certificado, y el navegador tiende a forzar HTTPS
> por su cuenta.

Al principio **carga en blanco**, y es normal: la máquina todavía está instalando los
paquetes de nginx y arrancando el servicio. Hay que darle un momento.

#### Añadido fuera del curso — falta la regla de firewall para el puerto 80

*(2026-08-12. No sale en la transcripción; se detectó al revisar el estado real del
proyecto, y sin esto el paso anterior no puede funcionar.)*

`mi-vpc-curso` se creó en modo **CUSTOM**, y una VPC custom **no trae ninguna regla de
firewall por defecto**. Las `default-allow-ssh`, `default-allow-http` y compañía solo
existen en la red `default` de cada proyecto, que es justo la que el módulo 1 decidió no
usar. En una VPC custom todo el ingreso está denegado hasta que lo abres tú.

En el proyecto solo existía la regla del ejercicio 5:

| Regla | Puerto | De dónde venía |
|---|---|---|
| `allow-ssh-custom` | `tcp:22` | Ejercicio 5 del módulo 1 |

Es decir: el SSH del final de este ejercicio funciona, pero **`http://IP-EXTERNA` no puede
responder nunca**, por muy bien que haya corrido el startup script. Faltaba abrir el 80:

```bash
gcloud compute firewall-rules create allow-http-custom \
    --direction=INGRESS --priority=1000 --network=mi-vpc-curso \
    --action=ALLOW --rules=tcp:80 --source-ranges=0.0.0.0/0 \
    --target-tags=web-server
```

Queda añadida a
[`setup-teraform/firewalls-network-tags.sh`](../setup-teraform/firewalls-network-tags.sh),
junto a la del 22, por el mismo criterio del ejercicio 8: si un ajuste hace falta para que
el entorno funcione, va al repositorio y no se hace solo a mano.

> **Cómo distinguir los dos síntomas**, que se parecen pero no son lo mismo:
>
> | Lo que ve el navegador | Qué pasa de verdad |
> |---|---|
> | Carga en blanco y acaba mostrando la página | nginx todavía se está instalando — es lo que cuenta el curso |
> | Se queda colgado hasta agotar el tiempo, sin responder | **falta la regla de firewall** — el paquete ni llega a la máquina |
>
> El primero se arregla esperando; el segundo, no.

El `--target-tags=web-server` es el mismo tag del ejercicio 5, así que la VM del ejercicio 6
ya lo lleva y hereda las dos reglas sin tocarla. Eso es exactamente lo que el apartado
anterior describe como *«el momento en que el módulo 1 empieza a rendir»*: al añadir una
capacidad nueva a la red, la máquina no se modifica.

> **Pendiente de higiene:** las dos reglas tienen `--source-ranges=0.0.0.0/0`. Para el 80 de
> un servidor web público es lo correcto; para el **22 no lo es**, deja el SSH expuesto a
> todo internet. Lo razonable sería restringirlo a tu IP (`--source-ranges=TU_IP/32`) o al
> rango de IAP (`35.235.240.0/20`). Se deja anotado para el módulo de seguridad.

#### Añadido fuera del curso — `ZONE_RESOURCE_POOL_EXHAUSTED` y el cambio a us-east1

*(2026-08-12. Segundo desvío respecto de la transcripción, este por causas ajenas al
proyecto.)*

Al lanzar el script, `gcloud` devolvió:

```
code: ZONE_RESOURCE_POOL_EXHAUSTED
message: The zone 'projects/.../zones/us-central1-a' does not have enough
         resources available to fulfill the request.
```

**No es un error del comando.** Significa que Google no tiene máquinas `e2-micro` libres en
esa zona en ese momento. Es la contrapartida de usar el tipo de la capa gratuita: al ser el
único gratis, es el más disputado y se agota a menudo. Se probaron **las cuatro zonas** de
`us-central1` (`a`, `b`, `c`, `f`) y todas devolvieron lo mismo.

La salida a esto tiene tres formas, y conviene entender qué se paga con cada una:

| Salida | Qué implica | Coste |
|---|---|---|
| Esperar y reintentar | La capacidad zonal se libera sola, pero no se sabe cuándo | Cero, pero bloquea |
| Subir a `e2-small` | Un flag; se queda en `us-central1` como el curso | Sale de la capa gratuita: ~0,017 USD/h |
| **Cambiar de región** | Subred nueva; `e2-micro` sigue gratis en `us-west1` y `us-east1` | **Cero** |

Se eligió la tercera. Una subred más en la VPC:

```bash
gcloud compute networks subnets create subred-us-east \
    --network=mi-vpc-curso --region=us-east1 --range=10.0.2.0/24
```

y la instancia en `us-east1-b` apuntando a ella. Salió a la primera.

> **El firewall no hubo que tocarlo, y eso es lo interesante.** Las reglas de GCP tienen
> alcance de **VPC**, no de subred, y seleccionan por *network tag*. Como la máquina nueva
> sigue llevando `web-server`, heredó `allow-ssh-custom` y `allow-http-custom` en una región
> distinta sin escribir una línea. La red se extendió a otro continente y la política de
> acceso vino sola.

Verificación, ya con la IP externa de la máquina de `us-east1`:

```bash
curl -I http://IP-EXTERNA
# HTTP/1.1 200 OK
# Server: nginx/1.22.1
```

Tardó unos 45 segundos en responder desde que la VM quedó en `RUNNING`: es el "carga en
blanco" del apartado anterior, el startup script todavía instalando paquetes.

#### El drift, y por qué importa

Aquí se cometió —y se corrigió— el error que el ejercicio 8 avisa: **la subred se creó a
mano con `gcloud`, pero la red la gestiona Terraform** ([`network.tf`](../setup-teraform/network.tf)).
El síntoma es inmediato:

```
$ terraform plan
Plan: 1 to add, 0 to change, 0 to destroy.
```

Terraform quería **crear** una subred que ya existía; el `apply` habría fallado con *already
exists*. El estado y la realidad habían dejado de coincidir. Se arregla en dos pasos:

```bash
# 1. Declararla en network.tf (resource "google_compute_subnetwork" "subnet_us_east")
# 2. Meter en el estado la que ya existe, sin recrearla:
terraform import google_compute_subnetwork.subnet_us_east \
    projects/gcp-data-engineer-muestra/regions/us-east1/subnetworks/subred-us-east
```

Después, `terraform plan` responde **`No changes. Your infrastructure matches the
configuration.`**

> `terraform import` **no toca nada en GCP**: solo escribe en el `.tfstate` que ese recurso
> existente pasa a estar gestionado. Es la herramienta para adoptar infraestructura creada
> por fuera, y la que evita tener que destruir y recrear algo que ya funciona.

La moraleja es la misma que la de la API del ejercicio 8, pero más cara de aprender: cuando
resuelvas una urgencia con un comando imperativo sobre infraestructura declarativa, **el
arreglo no termina hasta que el `plan` sale limpio**.

Para verificarlo desde dentro, se entra por SSH y se consulta el servicio:

```bash
sudo -i
service nginx status     # → active
```

El primer intento dio *command not found*: el `service` necesita privilegios, de ahí el
`sudo -i` antes.

Commit `curso 06`: en el repositorio quedan los dos scripts, el de creación y el de arranque.

---

## Ejercicio 7 — Managed Instance Groups, autohealing y autoescalado

### La teoría: mascotas frente a ganado

La imagen que resume el cambio de mentalidad de la nube:

| | Mascota (*pet*) | Ganado (*cattle*) |
|---|---|---|
| Qué es | Un servidor individual, con nombre | Instancias intercambiables |
| Si enferma | La cuidas, la arreglas, la mimas | La eliminas y pones otra |

**En la nube queremos ganado.** Los **MIG** (*Managed Instance Groups*) son lo que lo hace
posible: usan una **instance template** —una plantilla **inmutable**— para crear copias
idénticas.

### Los dos superpoderes

**Autohealing** — el MIG le pregunta a cada máquina cada cierto tiempo si sigue viva (le
lanza un *ping*, un health check). Si no responde o falla, levanta una nueva.

**Autoescalado** — si la CPU de las máquinas llega al 80%, el MIG añade más
automáticamente. Cuando la carga baja, las destruye para **ahorrar dinero**.

La segunda mitad del autoescalado es la que se olvida: escalar hacia abajo es tan importante
como escalar hacia arriba, porque es la que controla la factura.

### La práctica

Partida: *Compute Engine → Grupos de instancias* está vacío.

> **Antes de nada, parar la instancia del ejercicio 6** para que no siga generando coste.
> Este hábito se repite en todo el curso.

Un `setup-terraform/mig.tf` con dos recursos:

**`google_compute_instance_template`** — la plantilla:

| Campo | Valor |
|---|---|
| `name_prefix` | El prefijo de cada máquina del clúster |
| `machine_type` | `e2-micro`, pequeña en CPU y en memoria |
| `tags` | `web-server`, otra vez el del firewall |
| `disk.source_image` | Una imagen de Debian — el sistema operativo |
| `network_interface` | La subred `us-central1` creada en el módulo 1 |

**`google_compute_region_instance_group_manager`** — el grupo en sí:

| Campo | Valor |
|---|---|
| `target_size` | `2` — arranca con dos instancias |
| `base_instance_name` | `app` |
| `region` | Dónde se aloja |
| `version.instance_template` | La plantilla de arriba |

```bash
terraform apply
```

Aquí se ve algo que merece la pena señalar: **lo primero que hace `apply` es refrescar el
estado** de todo lo ya provisionado con Terraform —las tres APIs, la network y la
subnetwork— antes de proponer nada nuevo. Eso es el valor del estado: Terraform sabe qué
existe, así que solo planifica lo que falta.

Después anuncia los dos recursos, se confirma con `yes`, y los tiempos son muy distintos:
**la plantilla se crea al momento, el grupo de instancias tarda.** Refrescando la consola se
ve el contador de instancias subiendo de 0 a 2.

En la consola queda visible que la plantilla es la definida en Terraform (`e2-micro`, con la
red y subred propias) y que está **en uso por el MIG**. Cuando el estado pasa a OK, el grupo
muestra sus dos instancias, con la misma plantilla, conectables por SSH, y con opciones de
monitorización y edición.

Commit `curso 07`.

> **Un detalle que demuestra la teoría sin querer:** al final del ejercicio, la consola **no
> deja detener** las instancias del grupo. Es exactamente el autohealing haciendo su trabajo
> — el MIG entiende que una máquina parada es una máquina caída y la repondría. Para bajar un
> MIG se cambia su `target_size` o se destruye el grupo, no se apagan las máquinas una a una.

### Añadido fuera del curso — los cuatro errores del `mig.tf`

*(2026-08-12. El archivo no pasaba `terraform validate`; tres de los cuatro fallos no los
detecta el validador y habrían explotado en el `apply`.)*

**1. El recurso era el zonal, no el regional.** Es el único que corta el `validate`:

```
Error: Unsupported argument
  on mig.tf line 18: region = "us-east1"
An argument named "region" is not expected here.
```

`google_compute_instance_group_manager` es **zonal** y solo acepta `zone`. El regional es
otro recurso distinto:

```diff
- resource "google_compute_instance_group_manager" "mig" {
+ resource "google_compute_region_instance_group_manager" "mig" {
```

Merece la pena fijarse en el mensaje: Terraform no dice *«te falta un recurso regional»*,
dice *«este argumento no va aquí»*. El validador comprueba el esquema del recurso que
escribiste, no si elegiste el recurso correcto.

**2. `name = "app_mig"` — guion bajo.** GCP exige `[a-z]([-a-z0-9]*[a-z0-9])?` en los
nombres de recurso: minúsculas, dígitos y guiones **medios**. Corregido a `app-mig`.
`validate` no lo ve porque es una restricción de la API, no del esquema de Terraform; habría
fallado recién en el `apply`.

**3. La subred no coincidía con la región del MIG.** La plantilla apuntaba a `subnet_us`
(us-central1) y el MIG declaraba `us-east1`. Una instancia **no puede usar una subred de otra
región**. Corregido a `subnet_us_east`.

**4. `debian-11` → `debian-12`**, para que las máquinas del grupo sean iguales a
`servidor-web-1`.

Y un añadido que no era un error pero evita un `apply` fallido más adelante:

```hcl
lifecycle {
    create_before_destroy = true
}
```

Las *instance templates* son **inmutables** —el propio apunte lo dice—, así que cualquier
cambio obliga a crear una nueva. Sin esa cláusula, Terraform intenta destruir la vieja
mientras el MIG todavía la usa, y falla. La inmutabilidad no es solo teoría: tiene una
consecuencia práctica en el orden de las operaciones.

### El resultado, y lo que demuestra

```
NAME     LOCATION  SCOPE   BASE_INSTANCE_NAME  SIZE  TARGET_SIZE
app-mig  us-east1  region  app                 2     2
```

| Instancia | Zona |
|---|---|
| `app-2vfc` | us-east1-**b** |
| `app-hn2k` | us-east1-**c** |

**El MIG repartió las dos máquinas en zonas distintas sin que nadie se lo pidiera.** Eso es
lo que aporta frente a la VM del ejercicio 6: si `us-east1-b` cae, la otra sigue. Y de paso
resuelve el problema que bloqueó el ejercicio anterior — un MIG regional busca capacidad
zona por zona, así que el `ZONE_RESOURCE_POOL_EXHAUSTED` no lo detiene.

Los sufijos (`-2vfc`, `-hn2k`) los genera el MIG sobre el `base_instance_name`. Que no tengan
nombre propio es deliberado: son ganado, no mascotas.

> **Las máquinas del MIG no sirven nginx, y está bien así.** Dos ausencias que sorprenden al
> mirar la consola:
>
> | Falta | Por qué | Consecuencia |
> |---|---|---|
> | `access_config {}` en `network_interface` | Sin él GCP no asigna IP pública | No se las alcanza desde internet **ni ellas salen** a internet |
> | `metadata_startup_script` | La plantilla no define ninguno | Son Debian 12 recién nacidos, sin nada instalado |
>
> No está roto: el ejercicio 7 trata de la **mecánica** del MIG —plantilla inmutable,
> autohealing, reparto por zonas—, no de servir tráfico. Si se quisiera que sirvieran nginx
> como el ejercicio 6, harían falta las dos cosas a la vez: la IP externa **y** el startup
> script, porque sin salida a internet el `apt-get install` fallaría igual.

**Coste:** `target_size = 2` son dos `e2-micro` y la capa gratuita cubre **una sola al mes**.
Para bajar el grupo al terminar:

```bash
terraform destroy -target=google_compute_region_instance_group_manager.mig
```

---

## Ejercicio 8 — Snapshots y gestión de discos

### La teoría

El punto de partida: **los datos son lo único que no se puede reemplazar** si una máquina
virtual se borra. Todo lo demás se vuelve a levantar con un script.

En Compute Engine los **persistent disks** son **almacenamiento en red**: no están insertados
físicamente en el servidor. Esa separación es la que permite todo lo que viene después.

### Los snapshots son incrementales

Esto es *«lo genial de los snapshots en GCP»*:

- El **primer** backup tarda mucho, porque copia toda la máquina.
- El **segundo** solo copia **los bytes modificados** → muy rápido y muy barato.

### El truco de mover una máquina de continente

> ¿Cómo muevo una máquina virtual de Estados Unidos a Europa?

**No puedes moverla.** Haces un snapshot del disco y creas un **disco nuevo en Europa**
usando ese snapshot como fuente. Es el patrón real de migración entre regiones, y solo
funciona porque el disco es un recurso independiente de la máquina.

### La práctica

Partida: *Snapshots* está vacío. Desde la consola se puede crear uno o **programarlo**;
aquí se hace con Python y la librería cliente de Google Cloud.

Se ordena el repositorio: una carpeta `compute-engine/` donde se meten el script de creación
de la instancia y el startup script del ejercicio 6, y se añade `backup_vm.py`.

Lo que hace el código: lista los discos, **selecciona el disco** por `project_id`, zona y
nombre, crea un objeto `Snapshot` y lo **inserta**.

Como en el ejercicio 3, hay que añadirle la parte de línea de comandos con `argparse`. Los
cuatro argumentos: `--project-id`, `--disk-name`, `--snapshot-name`, `--zone`.

```bash
pip install google-cloud-compute
```

#### Averiguar el nombre del disco

Es el dato que no se sabe de memoria, y se saca con dos comandos:

```bash
gcloud compute instances list                    # ver las instancias
gcloud compute instances describe servidor-web-1 # ver sus discos y su zona
```

En la salida de `describe` aparecen los discos adjuntos y, **al final**, la zona.

#### Los cuatro tropiezos, que son la parte útil

| Síntoma | Causa | Arreglo |
|---|---|---|
| El script no acepta los valores | Se pasaron como posicionales | Usar los flags: `--project-id`, `--disk-name`... |
| Error de API deshabilitada | Falta `compute.googleapis.com` | **Añadirla al `main.tf` de Terraform**, no habilitarla a mano |
| Error de proyecto | Project ID sin el sufijo `-01` | Corregirlo |
| `No se encuentra el disco` | El nombre del disco era de otra instancia | Consultar el nombre real en la consola |

El segundo es el que enseña algo de criterio: cuando falta una API, la tentación es darle a
*Habilitar* en la consola. Añadirla al `main.tf` mantiene el entorno **reproducible** —el
siguiente que clone el repo tendrá la API activada sin saber que hacía falta.

#### Y un hábito que copiar

Se crea un `compute-engine/commands.sh` donde se van guardando los comandos que se han
lanzado (`instances list`, `instances describe`, la llamada a Python) **para tenerlos a
mano**. No es un script pensado para ejecutarse: es un cuaderno de comandos, y evita volver
a deducirlos dentro de tres semanas.

Con el nombre de disco correcto, la consola muestra el snapshot creándose y luego terminado.
Commit `curso 08`: la carpeta `compute-engine` queda con sus cuatro scripts.

---

## Ejercicio 9 — OS Login y el fin de las llaves SSH

### La teoría

El problema, planteado a escala: una empresa con **500 ingenieros**. Gestionar sus llaves
públicas SSH a mano en cada servidor Linux es imposible y peligroso.

Y la pregunta que lo remata: **¿qué pasa cuando alguien deja la empresa?** Tienes que ir
servidor por servidor borrando su llave. Basta que se te escape uno.

**OS Login** es la solución de Google: vincula la **cuenta de Google** (Gmail o corporativa)
con el **usuario de Linux**. Cuando intentas hacer SSH, Google verifica **en tiempo real** si
tienes permisos IAM en el proyecto:

- Empleado activo → entras.
- Acceso revocado → el SSH te rechaza **al instante**, sin tocar ningún servidor.

Además permite **autenticación en dos factores**.

El cambio de fondo: el acceso deja de ser un archivo repartido por las máquinas y pasa a ser
una **consulta a IAM**. Revocar es un solo gesto en un solo sitio.

### La práctica

Primero, **arrancar la instancia del ejercicio 6**, que se había parado.

Un `os-login-ssh.sh` con dos comandos, y no hace falta más:

```bash
# 1. Forzar OS Login a nivel de PROYECTO, vía metadata
gcloud compute project-info add-metadata \
    --metadata enable-oslogin=TRUE

# 2. Conectarse
gcloud compute ssh servidor-web-1
```

Con OS Login habilitado en el proyecto, la conexión al servidor del ejercicio 6 funciona
directamente. Dentro se comprueba el nginx que instaló el startup script:

```bash
sudo -i
service nginx status   # active
service nginx stop
service nginx status   # enabled, pero inactive
exit
```

> Fíjate en la diferencia entre las dos palabras de la última salida: **`enabled`** significa
> que el servicio arrancará solo al reiniciar la máquina; **`active`** significa que está
> corriendo ahora. Un servicio puede estar habilitado y parado a la vez, que es justo lo que
> muestra ese `stop`.

Commit `curso 09`. También se puede comprobar que OS Login está activo entrando por SSH
**desde el botón de la consola**, que usa el mismo mecanismo.

---

## Lo que se lleva del módulo 2

### El hilo: de la mascota al ganado

El módulo está construido como una progresión, no como cuatro temas sueltos:

| Ejercicio | Qué añade |
|---|---|
| 6 | Una VM **zonal**: funciona, pero es un único punto de fallo |
| 7 | Un MIG **regional**: máquinas desechables que se reponen solas |
| 8 | Lo que **no** es desechable —los datos— con backups incrementales |
| 9 | Quién puede entrar, resuelto por **IAM** en vez de por llaves |

### El principio repetido: nada a mano

Cada ejercicio sustituye un gesto manual por uno automatizado. Es el mismo *nada por
defecto* del módulo 1, aplicado ahora a las operaciones:

| En vez de... | Se usa |
|---|---|
| Entrar por SSH e instalar nginx | **Startup script** en la metadata |
| Cuidar cada servidor | **Instance template** + MIG |
| Hacer backups cuando te acuerdas | **Python** contra la API (y se pueden programar) |
| Repartir llaves SSH | **OS Login** contra IAM |

### La metadata como canal de configuración

Aparece dos veces en el módulo, y en dos niveles distintos:

| Nivel | Clave | Efecto |
|---|---|---|
| Instancia (ej. 6) | `startup-script` | Qué ejecuta la máquina al nacer |
| Proyecto (ej. 9) | `enable-oslogin` | Cómo se autentica el acceso a **todas** las máquinas |

Merece la pena reconocer el patrón: la metadata es el canal por el que se configura Compute
Engine desde fuera, y lo que se pone a nivel de proyecto lo heredan todas las instancias.

### Las herramientas, y por qué cada una

| Ejercicio | Herramienta | Enfoque |
|---|---|---|
| 6 — VM con nginx | `gcloud` en Bash | Una creación puntual |
| 7 — MIG | Terraform | Infraestructura que debe poder recrearse igual |
| 8 — Snapshots | Python + SDK | Lógica y parámetros; y se puede programar |
| 9 — OS Login | `gcloud` en Bash | Un ajuste de configuración del proyecto |

Se mantiene el criterio del módulo 1: **declarativo para la infraestructura, imperativo para
las operaciones.**

### Higiene de costes

Dos recordatorios prácticos que aparecen en el módulo: **parar las instancias** al terminar
cada ejercicio, y saber que un **MIG no se apaga apagando sus máquinas** —hay que bajar su
`target_size` o destruir el grupo, porque el autohealing las repondrá.
