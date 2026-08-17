import argparse

from google.cloud import compute_v1


def create_snapshot(project_id, disk_name, snapshot_name, zone):
    """Creates a snapshot de un disco en Google Cloud Compute Engine."""
    disk_client = compute_v1.DisksClient()
    disk= f"projects/{project_id}/zones/{zone}/disks/{disk_name}"
    snapshot = compute_v1.Snapshot(name=snapshot_name, source_disk=disk)

    snap_client = compute_v1.SnapshotsClient()
    op = snap_client.insert(project=project_id, snapshot_resource=snapshot)
    op.result()  # esperar a que la operación se complete
    print(f"Snapshot '{snapshot_name}' creado para el disco '{disk_name}' en el proyecto '{project_id}'.")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Crea un snapshot de un disco de Compute Engine.",
        # Muestra los valores por defecto en el -h, que si no quedan invisibles.
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    # Van como flags, no como posicionales: el orden de cuatro cadenas sueltas
    # es imposible de recordar y equivocarse no da error, da un snapshot del
    # disco equivocado.
    parser.add_argument("--project-id", required=True, help="ID del proyecto de GCP.")
    parser.add_argument("--disk-name", required=True, help="Nombre del disco a copiar.")
    parser.add_argument("--snapshot-name", required=True, help="Nombre del snapshot a crear.")
    parser.add_argument("--zone", required=True, help="Zona donde vive el disco, p. ej. us-east1-b.")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    # argparse convierte --project-id en args.project_id (guion -> guion bajo).
    create_snapshot(
        project_id=args.project_id,
        disk_name=args.disk_name,
        snapshot_name=args.snapshot_name,
        zone=args.zone,
    )