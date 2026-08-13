#!/bin/bash
# Startup script del ejercicio 6: lo ejecuta el agente de Google al arrancar la
# VM por primera vez, y lo hace como root (por eso no lleva sudo).
# El shebang es obligatorio: sin el, el agente no sabe con que interprete
# correrlo, no instala nada y no deja ningun error visible.
apt-get update
apt-get install -y nginx
systemctl start nginx

# start lo levanta ahora; enable hace que vuelva a levantarse tras un reinicio.
systemctl enable nginx
