#!/bin/bash
# La zona del curso era us-central1-a, pero las cuatro zonas de us-central1
# devolvian ZONE_RESOURCE_POOL_EXHAUSTED para e2-micro. us-east1 tambien esta
# en la capa gratuita, asi que el ejercicio sigue costando cero.
# La subred subred-us-east esta declarada en network.tf.
# Ruta del propio script, para poder lanzarlo desde cualquier directorio.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

gcloud compute instances create "servidor-web-1" \
    --zone "us-east1-b" \
    --machine-type "e2-micro" \
    --subnet "subred-us-east" \
    --tags=web-server \
    --metadata-from-file startup-script="$DIR/startup-script.sh"
