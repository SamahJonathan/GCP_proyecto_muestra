gcloud compute firewall-rules create allow-ssh-custom --direction=INGRESS --priority=1000 --network=mi-vpc-curso --action=ALLOW --rules=tcp:22 --source-ranges=0.0.0.0/0 --target-tags=web-server

# mi-vpc-curso es una VPC en modo CUSTOM: no hereda ninguna regla por defecto,
# asi que sin esta segunda regla el nginx del ejercicio 6 queda inalcanzable.
gcloud compute firewall-rules create allow-http-custom --direction=INGRESS --priority=1000 --network=mi-vpc-curso --action=ALLOW --rules=tcp:80 --source-ranges=0.0.0.0/0 --target-tags=web-server
