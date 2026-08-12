resource "google_compute_network" "vpc_network"{
    name = "mi-vpc-curso"
    auto_create_subnetworks = false 
}

resource "google_compute_subnetwork" "subnet_us" {
    name = "subred-us"
    ip_cidr_range = "10.0.1.0/24"
    region = "us-central1"
    network = google_compute_network.vpc_network.id
}

# Segunda subred, en us-east1. Hizo falta porque us-central1 no tenia capacidad
# de e2-micro en ninguna de sus cuatro zonas (ZONE_RESOURCE_POOL_EXHAUSTED).
# e2-micro sigue en la capa gratuita en us-east1, asi que el ejercicio no cuesta nada.
resource "google_compute_subnetwork" "subnet_us_east" {
    name = "subred-us-east"
    ip_cidr_range = "10.0.2.0/24"
    region = "us-east1"
    network = google_compute_network.vpc_network.id
}

# creando un red y subred en un rango determinado