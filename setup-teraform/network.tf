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

# creando un red y subred en un rango determinado 