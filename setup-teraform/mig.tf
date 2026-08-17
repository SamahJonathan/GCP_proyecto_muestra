resource "google_compute_instance_template" "tpl" {
    name_prefix  = "tpl-"
    machine_type = "e2-micro"
    tags         = ["web-server"]

    disk {
        source_image = "debian-cloud/debian-12"
    }

    network_interface {
        # La subred debe estar en la MISMA region que el MIG (us-east1).
        subnetwork = google_compute_subnetwork.subnet_us_east.id
    }

    # Las plantillas son inmutables: cualquier cambio obliga a crear una nueva.
    # Sin esto, Terraform intenta destruir la vieja mientras el MIG aun la usa.
    lifecycle {
        create_before_destroy = true
    }
}

# Regional, no zonal: reparte las instancias entre las zonas de us-east1 y
# reintenta donde haya capacidad. El recurso zonal (google_compute_instance_group_manager)
# no acepta "region", solo "zone".
resource "google_compute_region_instance_group_manager" "mig" {
    name               = "app-mig"
    base_instance_name = "app"
    region             = "us-east1"

    version {
        instance_template = google_compute_instance_template.tpl.id
    }

    target_size = 2
}
