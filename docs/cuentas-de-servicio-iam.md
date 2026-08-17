# Cuentas de servicio, permisos y roles en GCP

Explicación del script `setup-iam/setup-iam.sh`: qué es una cuenta de servicio, cómo se le
asigna un rol y cómo encaja todo en el modelo IAM de Google Cloud.

---

## 1. Qué es una cuenta de servicio

Una **cuenta de servicio** (*service account*) es una identidad para **máquinas**, no para
personas. La usa una aplicación, una VM, un pipeline de CI o Terraform para autenticarse
contra Google Cloud.

| | Cuenta de usuario | Cuenta de servicio |
|---|---|---|
| Quién la usa | Una persona | Un programa |
| Cómo entra | Contraseña + navegador | Clave o identidad adjunta al recurso |
| Ejemplo | `jona.samah@gmail.com` | `dev-deployer@proyecto.iam.gserviceaccount.com` |

La idea de fondo: **el código no debe correr con tus credenciales personales**. Si una
aplicación usa tu cuenta, hereda *todos* tus permisos, y el día que te vayas del proyecto o
cambies la contraseña, deja de funcionar. Con una cuenta de servicio, la identidad pertenece
al proyecto y tiene exactamente los permisos que necesita.

### Crearla

```bash
gcloud iam service-accounts create dev-deployer --display-name "Deployer SA"
```

Dos puntos a tener en cuenta:

- **`service-accounts` va en plural.** En singular `gcloud` no reconoce el comando.
- `dev-deployer` es el **ID**, permanente y no modificable. `"Deployer SA"` es el
  **display name**, solo decorativo y cambiable cuando quieras.

### El correo que se genera

Al crearla, GCP le asigna automáticamente una dirección con este formato fijo:

```
NOMBRE@ID-DEL-PROYECTO.iam.gserviceaccount.com
```

En nuestro caso:

```
dev-deployer@gcp-data-engineer-muestra.iam.gserviceaccount.com
```

> Fíjate en `.iam.gserviceaccount.com`: **todo con puntos**. Escribirlo con guion
> (`.iam-gserviceaccount.com`) es un error frecuente y el binding fallará.

Esa dirección es el identificador real de la cuenta. Es lo que se usa en todos los comandos
posteriores; el nombre corto ya no vuelve a aparecer.

---

## 2. El modelo IAM: quién, qué y dónde

IAM (*Identity and Access Management*) responde siempre a la misma pregunta:

> **¿Quién** puede hacer **qué** sobre **qué recurso**?

Esos tres elementos tienen nombre propio:

| Elemento | Nombre en GCP | En nuestro script |
|---|---|---|
| Quién | **member** (o *principal*) | `serviceAccount:dev-deployer@...` |
| Qué | **role** | `roles/compute.viewer` |
| Dónde | **resource** | el proyecto `gcp-data-engineer-muestra` |

La unión de los tres es un **binding** (vinculación). El conjunto de todos los bindings de un
recurso es su **política IAM**.

### El comando

```bash
gcloud projects add-iam-policy-binding gcp-data-engineer-muestra \
    --member="serviceAccount:dev-deployer@gcp-data-engineer-muestra.iam.gserviceaccount.com" \
    --role="roles/compute.viewer"
```

Leído en orden: *sobre el proyecto `gcp-data-engineer-muestra`, añade un binding que le da a
la cuenta `dev-deployer` el rol `compute.viewer`*.

> La `\` al final de línea es una **continuación**: le dice a bash que el comando sigue
> abajo. Debe llevar **un espacio antes** y no puede haber nada después, ni siquiera un
> espacio invisible.

---

## 3. El prefijo del member

`--member` nunca lleva el correo suelto. Siempre va precedido del **tipo de identidad**:

| Prefijo | Para qué |
|---|---|
| `user:` | Una persona — `user:jona.samah@gmail.com` |
| `serviceAccount:` | Una cuenta de servicio |
| `group:` | Un grupo de Google |
| `domain:` | Todos los usuarios de un dominio |
| `allUsers` | **Cualquiera en internet**, sin autenticar |
| `allAuthenticatedUsers` | Cualquier cuenta de Google |

Los dos últimos hacen el recurso público. Se usan en casos concretos (una web estática en
Cloud Storage) y son la causa habitual de las filtraciones de datos que salen en las noticias.
Úsalos solo si sabes exactamente por qué.

Ojo con las mayúsculas: es `serviceAccount`, en *camelCase*. `serviceaccount` falla.

---

## 4. Los roles

Un **rol** es un paquete de permisos individuales. Los permisos sueltos
(`compute.instances.list`, `compute.instances.create`...) no se asignan uno a uno: se agrupan
en roles.

### Formato del nombre

```
roles/SERVICIO.NIVEL
       │        └── viewer, editor, admin, instanceAdmin...
       └── compute, storage, bigquery, iam...
```

### Los tres tipos

| Tipo | Ejemplo | Cuándo |
|---|---|---|
| **Básicos** | `roles/viewer`, `roles/editor`, `roles/owner` | Heredados de antes de IAM. **Evítalos**: son enormes y afectan a todos los servicios |
| **Predefinidos** | `roles/compute.viewer` | Lo normal. Google los mantiene y actualiza |
| **Personalizados** | los que tú definas | Cuando ningún predefinido encaja |

### El rol de este script

`roles/compute.viewer` es de **solo lectura**. Su descripción oficial:

> *Read-only access to get and list information about all Compute Engine resources,
> including instances, disks, and firewalls. Allows getting and listing information about
> disks, images, and snapshots, but does not allow reading the data stored on them.*

Es decir: puede **listar y consultar** instancias, discos y reglas de firewall. No puede
crear, modificar ni destruir nada, y tampoco puede leer el contenido de los discos.

### Principio de menor privilegio

Es la idea que menciona el comentario del script: **dar el mínimo permiso que permita hacer
el trabajo, y ni uno más**. Si la cuenta se ve comprometida, el daño queda acotado.

En la práctica se traduce en dos hábitos:

- Empezar por un rol restrictivo y ampliarlo solo cuando algo falle por permisos
- Nunca usar `roles/owner` o `roles/editor` para automatización

Una consulta útil para saber qué rol pedir:

```bash
# Buscar roles que contengan un permiso concreto
gcloud iam roles list --filter="includedPermissions:compute.instances.create"
```

### Otros roles de Compute, por si el alcance cambia

| Rol | Permite |
|---|---|
| `roles/compute.viewer` | Solo consultar |
| `roles/compute.instanceAdmin.v1` | Crear, modificar y borrar instancias |
| `roles/compute.admin` | Control total sobre Compute Engine |

---

## 5. `add` frente a `set`: por qué importa

```bash
gcloud projects add-iam-policy-binding ...    # añade un binding
gcloud projects set-iam-policy ...            # reemplaza TODA la política
```

`add-iam-policy-binding` es aditivo y seguro: respeta lo que ya había.

`set-iam-policy` sustituye la política completa por la del archivo que le pases. Si ese
archivo está incompleto, **borras los permisos de todos los demás**, incluido posiblemente el
tuyo, y te quedas fuera del proyecto. Se usa en automatización seria, siempre partiendo de un
`get-iam-policy` previo.

Para quitar un binding existe el simétrico:

```bash
gcloud projects remove-iam-policy-binding gcp-data-engineer-muestra \
    --member="serviceAccount:dev-deployer@gcp-data-engineer-muestra.iam.gserviceaccount.com" \
    --role="roles/compute.viewer"
```

---

## 6. Idempotencia

El script **no** se puede ejecutar dos veces sin más:

| Comando | Al repetirlo |
|---|---|
| `service-accounts create` | ❌ Falla: `Service account dev-deployer already exists` |
| `add-iam-policy-binding` | ✅ Sin efecto, el binding ya está |

No es grave, pero explica el error si vuelves a lanzarlo. Es una de las diferencias con
Terraform: allí el estado sabe qué existe y `apply` no duplica nada.

---

## 7. Comprobar el resultado

```bash
# Listar las cuentas de servicio del proyecto
gcloud iam service-accounts list

# Ver qué roles tiene asignados esta cuenta concreta
gcloud projects get-iam-policy gcp-data-engineer-muestra \
    --flatten="bindings[].members" \
    --filter="bindings.members:dev-deployer@gcp-data-engineer-muestra.iam.gserviceaccount.com" \
    --format="table(bindings.role)"

# Ver la política completa del proyecto
gcloud projects get-iam-policy gcp-data-engineer-muestra
```

### Ejecutar el script

```bash
cd setup-iam
bash setup-iam.sh
```

Se lanza con `bash` porque el archivo no tiene *shebang* (`#!/usr/bin/env bash`). Así no hace
falta darle permisos de ejecución.

---

## 8. Errores frecuentes

Los cuatro que aparecieron al revisar este script, más otros habituales:

| Escrito | Correcto | Síntoma |
|---|---|---|
| `iam service-account create` | `service-accounts` (plural) | `Invalid choice: 'service-account'` |
| `--member= "..."` (con espacio) | `--member="..."` | `argument --member: expected one argument` |
| `.iam-gserviceaccount.com` | `.iam.gserviceaccount.com` | El binding se crea sobre una identidad inexistente |
| `roles/compute.viver` | `roles/compute.viewer` | `The role named roles/compute.viver was not found` |
| `serviceaccount:` | `serviceAccount:` | `Invalid principal type` |
| `"..."\` sin espacio | `"..." \` | Argumentos pegados, error confuso |

El tercero es especialmente traicionero: `gcloud` **no valida** que la cuenta exista al crear
el binding. El comando dice que todo fue bien y el fallo solo aparece más tarde, cuando la
aplicación intenta autenticarse.

---

## 9. Sobre las claves: lo que este script *no* hace

Existe un comando para generar una clave descargable de la cuenta de servicio:

```bash
gcloud iam service-accounts keys create clave.json --iam-account=...
```

**Este script no lo usa, y es lo correcto.** Ese archivo `.json` es una credencial permanente
que no caduca: si acaba en un repositorio o en un chat, cualquiera tiene los permisos de la
cuenta hasta que alguien la revoque a mano. Es la fuga de seguridad más común en GCP.

Las alternativas que no requieren archivo:

- **Dentro de GCP** — adjuntar la cuenta de servicio a la VM, el contenedor o la función.
  Google inyecta las credenciales automáticamente.
- **Fuera de GCP** (GitHub Actions, otro cloud) — *Workload Identity Federation*.
- **En local, para desarrollo** — `gcloud auth application-default login` con tu cuenta
  personal, que es lo que estamos usando con Terraform.

Si algún día generas una clave, asegúrate de que `*-key.json` y `*service-account*.json` están
en el `.gitignore` — ya lo están en este proyecto.

---

## 10. Roles personalizados: `custom_role.py`

Los roles predefinidos son paquetes cerrados. A veces ninguno encaja: en Compute Engine,
`compute.viewer` no deja arrancar máquinas y `compute.instanceAdmin.v1` deja además crearlas
y borrarlas. Si solo quieres **encender y apagar**, no hay término medio.

Ahí entra el **rol personalizado**: tú eliges los permisos exactos, uno a uno. Es el principio
de menor privilegio llevado al extremo.

### El script

```python
from google.cloud import iam_admin_v1


def create_role(project_id, role_id):
    client = iam_admin_v1.IAMClient()

    # El recurso donde vive el rol. Va en plural: projects/ID
    parent = f"projects/{project_id}"

    role = iam_admin_v1.Role(
        title="VM Starter Stopper",
        included_permissions=["compute.instances.start", "compute.instances.stop"],
        # GA = rol estable. El enum está anidado dentro de Role.
        stage=iam_admin_v1.Role.RoleLaunchStage.GA,
    )

    request = iam_admin_v1.CreateRoleRequest(
        parent=parent,
        role_id=role_id,
        role=role,
    )
    response = client.create_role(request=request)
    print(f"Rol creado : {response.name}")
    return response


if __name__ == "__main__":
    create_role("gcp-data-engineer-muestra", "vmStarterStopper")
```

Se autentica solo, sin credenciales en el código: la librería usa **ADC**, el mismo mecanismo
que Terraform. Por eso hizo falta `gcloud auth application-default login`.

### Las tres piezas

**`parent`** — dónde vive el rol. Formato `projects/ID`, **en plural**. Los roles
personalizados se crean a nivel de proyecto o de organización; no existen "sueltos".

**`Role`** — la definición. Sus campos:

| Campo | Para qué |
|---|---|
| `title` | Nombre visible en la consola |
| `included_permissions` | La lista de permisos. Es el contenido real del rol |
| `stage` | Madurez del rol |
| `description` | Opcional, texto libre |

**`role_id`** — el identificador permanente (`vmStarterStopper`). No admite puntos, y por
convención se escribe en camelCase. Es lo que aparecerá en el nombre completo del rol.

### El `stage`

Etiqueta la madurez del rol; no cambia lo que permite hacer. Valores disponibles:

```
ALPHA · BETA · GA · DEPRECATED · DISABLED · EAP
```

`GA` (*General Availability*) es el normal para un rol en uso. `DISABLED` es útil para
desactivar un rol temporalmente sin borrarlo.

> El enum está **anidado dentro de `Role`**: la ruta es
> `iam_admin_v1.Role.RoleLaunchStage.GA`. No cuelga de `iam_admin_v1` directamente, que es el
> error fácil de cometer.

### Ejecutar y comprobar

```bash
python3 setup-iam/custom_role.py
```

Salida esperada:

```
Rol creado : projects/gcp-data-engineer-muestra/roles/vmStarterStopper
```

```bash
# Consultarlo
gcloud iam roles describe vmStarterStopper --project=gcp-data-engineer-muestra

# Listar todos los personalizados del proyecto
gcloud iam roles list --project=gcp-data-engineer-muestra
```

### Asignarlo a la cuenta de servicio

Crear el rol no se lo da a nadie. Hace falta el binding, igual que con los predefinidos —
solo cambia el nombre, que ahora lleva la ruta del proyecto en vez de `roles/`:

```bash
gcloud projects add-iam-policy-binding gcp-data-engineer-muestra \
    --member="serviceAccount:dev-deployer@gcp-data-engineer-muestra.iam.gserviceaccount.com" \
    --role="projects/gcp-data-engineer-muestra/roles/vmStarterStopper"
```

| Tipo de rol | Cómo se referencia |
|---|---|
| Predefinido | `roles/compute.viewer` |
| Personalizado de proyecto | `projects/ID/roles/miRol` |
| Personalizado de organización | `organizations/ID/roles/miRol` |

### Nota práctica sobre los permisos elegidos

`compute.instances.start` y `compute.instances.stop` permiten la acción, pero no **ver** las
máquinas. Una identidad con solo estos dos permisos puede arrancar una instancia si conoce su
nombre exacto, y no podrá listarlas ni consultar su estado.

Si el rol va a usarlo una persona o una herramienta que necesite localizar la máquina primero,
suelen añadirse:

```python
included_permissions=[
    "compute.instances.start",
    "compute.instances.stop",
    "compute.instances.get",
    "compute.instances.list",
]
```

Para averiguar qué permisos exactos incluye un rol predefinido, y copiar de ahí:

```bash
gcloud iam roles describe roles/compute.instanceAdmin.v1
```

### Errores de ejecución

| Error | Causa | Solución |
|---|---|---|
| `403 Permission denied on 'iam.roles.create'` | Falta `roles/iam.roleAdmin` u owner | Pedir el rol en el proyecto |
| `409 A role named ... already exists` | Ya se ejecutó antes | Borrarlo o cambiar el `role_id` |
| `ModuleNotFoundError: google.cloud` | Falta la librería | `pip install google-cloud-iam` |

### El borrado tarda 7 días

```bash
gcloud iam roles delete vmStarterStopper --project=gcp-data-engineer-muestra
```

GCP **no borra los roles al momento**: los marca como *deleted* durante 7 días. En ese
periodo no puedes crear otro con el mismo ID, pero sí recuperarlo:

```bash
gcloud iam roles undelete vmStarterStopper --project=gcp-data-engineer-muestra
```

Es una salvaguarda: borrar un rol en uso quita permisos a todo el que lo tenga asignado.

### Lo mismo en Terraform

Este script es imperativo: se ejecuta, crea, y nadie lleva la cuenta. El equivalente
declarativo, coherente con el resto del proyecto, sería:

```hcl
resource "google_project_iam_custom_role" "vm_starter_stopper" {
  role_id     = "vmStarterStopper"
  title       = "VM Starter Stopper"
  permissions = ["compute.instances.start", "compute.instances.stop"]
}
```

La diferencia es la de siempre: Terraform guarda el estado, así que `apply` dos veces no
duplica nada, y quitar el bloque destruye el rol. El script de Python falla al repetirlo y no
sabe deshacer lo que hizo.

---

## Resumen en cuatro líneas

1. Se crea una **identidad** para la máquina: la cuenta de servicio.
2. Se le concede un **rol** sobre un **recurso**: el binding IAM.
3. El rol asignado es de solo lectura, siguiendo el **principio de menor privilegio**.
4. Cuando ningún rol predefinido encaja, se define uno **personalizado** con los permisos
   exactos.
