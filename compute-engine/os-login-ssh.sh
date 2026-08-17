#habilitar OS login a nivel de proyecto (o instancia)
# Al ponerlo en el proyecto lo heredan TODAS las instancias.
# La clave es enable-oslogin, sin guion entre "os" y "login": la metadata acepta
# cualquier nombre sin quejarse, asi que un enable-os-login no da error y no
# habilita nada.

gcloud compute project-info add-metadata --metadata enable-oslogin=TRUE

# Comprobar que quedo puesta
gcloud compute project-info describe --format="value(commonInstanceMetadata.items)"


# La VM quedo TERMINATED en el ejercicio 8: hay que arrancarla antes de entrar.
gcloud compute instances start servidor-web-1 --zone=us-east1-b

#conectar
gcloud compute ssh servidor-web-1 --zone=us-east1-b