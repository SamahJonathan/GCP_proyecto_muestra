# Apuntes del curso — Módulo 4: Almacenamiento y datos

Notas de la transcripción del módulo 4. De momento cubre el **ejercicio 14**; el archivo se
irá ampliando con el resto del módulo.

Continúa desde [`apuntes-modulo-3-contenedores.md`](apuntes-modulo-3-contenedores.md).

> Apuntes tomados de la transcripción, no de una ejecución propia.

---

## Ejercicio 14 — Cloud Storage, clases de almacenamiento y *lifecycle rules*

### La teoría

**Cloud Storage** es almacenamiento **de objetos**. La distinción no es cosmética:

> Piensa en **archivos**, no en bloques de disco.

Y es **inmutable**: si editas un archivo, en realidad lo estás **sobrescribiendo por
completo**. No hay modificación parcial de un objeto.

Es la diferencia con los *persistent disks* del módulo 2, que sí son bloques y sí se montan
en una máquina. Un bucket no se monta: se accede por API.

### Las clases de almacenamiento, que es lo que toca el bolsillo

| Clase | Frecuencia de acceso | Caso típico |
|---|---|---|
| **Standard** | Datos calientes, acceso diario | Lo que sirve tu web ahora mismo |
| **Nearline** | Datos tibios, ~una vez al mes | Backups recientes |
| **Coldline** | Datos fríos, ~una vez al trimestre | Archivo que casi no se toca |
| **Archive** | Datos congelados, años sin tocarse | Histórico por si hay auditoría |

Y la regla que hay que memorizar, porque es contraintuitiva:

> **Cuanto más frío es el almacenamiento, más barato es guardarlo — pero más caro es
> leerlo.**

Por eso elegir Archive «porque es lo más barato» puede salir carísimo: si resulta que
necesitas leer esos datos a menudo, pagas la recuperación cada vez. La clase correcta
depende del **patrón de acceso**, no del tamaño.

### Las *lifecycle rules*

Son reglas que mueven o borran objetos solos, según su edad. Permiten decir cosas como *«si
el archivo tiene más de 30 días, pásalo a Coldline»* sin que nadie tenga que acordarse.

Es la automatización del ahorro: los datos se enfrían solos con el tiempo, que es lo que
hacen de verdad.

### La práctica

Partida: en *Cloud Storage → Buckets* ya hay un par de buckets **que no creó nadie a mano**
— los generaron Cloud Run y Cloud Functions en el módulo 3 para guardar el código y las
imágenes de los contenedores.

El objetivo: un bucket que **borra sus archivos a los 30 días**, para que no se disparen los
costes ni se acumulen ficheros sin control.

Se crea `setup-terraform/storage.tf` con un `google_storage_bucket`:

| Campo | Valor |
|---|---|
| `name` | Un nombre **único a nivel mundial** |
| `lifecycle_rule.condition.age` | `30` días |
| `lifecycle_rule.action.type` | `Delete` |

```bash
cd setup-terraform
terraform apply
```

> **Detalle: la práctica no hace lo que promete la teoría.** La teoría habla de *pasar a
> Coldline* a los 30 días; la práctica hace un **`Delete`**. Son dos acciones distintas de
> `lifecycle_rule` —`SetStorageClass` y `Delete`— y conviene no confundirlas: una ahorra
> moviendo, la otra ahorra destruyendo.

#### Los dos tropiezos

| Síntoma | Causa | Arreglo |
|---|---|---|
| `apply` no detecta ningún cambio | **El archivo no estaba guardado** | Guardar y relanzar |
| `request bucket name is not available` | El nombre del bucket ya existe **en el mundo** | Elegir otro más específico |

El segundo es el concepto importante, no una anécdota: **el espacio de nombres de los
buckets es global y compartido por todos los clientes de Google Cloud**. No basta con que
sea único en tu proyecto. Por eso `mi-bucket-unico-12345` estaba cogido y hubo que pasar a
uno con el nombre del proyecto dentro.

Es un caso más de lo que ya se vio con las redes y los discos: en GCP **el nombre es la
dirección del recurso**, y aquí el ámbito de esa dirección es el planeta entero.

Tras corregirlo, el bucket se crea y en la consola aparece, en *Configuración del ciclo de
vida*, la regla: **borrar 30 días o más después de la creación del objeto**.

Commit `curso 14`.

---

## Lo que se lleva del ejercicio 14

- **Objetos, no bloques.** Un bucket no es un disco: es inmutable y se accede por API.
- **La clase se elige por patrón de acceso**, no por tamaño. Frío es barato de guardar y
  caro de leer.
- **Las lifecycle rules automatizan el ahorro**, y son la única forma realista de que un
  bucket no crezca para siempre.
- **El nombre de un bucket es global.** Es el primer recurso del curso cuyo nombre compite
  con el de todos los demás usuarios de Google Cloud.
