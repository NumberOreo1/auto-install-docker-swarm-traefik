#!/bin/bash

# Forcer l'exécution avec sudo
if [[ $EUID -ne 0 ]]; then
  echo "❌ Ce script doit être exécuté avec sudo : sudo $0"
  exit 1
fi

set -e

### === MENU INTERACTIF === ###
echo "Que souhaitez-vous installer ?"
echo "1) Installer uniquement Docker"
echo "2) Installer Docker + Swarm"
echo "3) Installer Docker + Swarm + Traefik"
read -p "👉 Entrez le numéro de votre choix [1-3] : " CHOICE

case $CHOICE in
  1)
    INSTALL_DOCKER=true
    INSTALL_SWARM=false
    INSTALL_TRAEFIK=false
    ;;
  2)
    INSTALL_DOCKER=true
    INSTALL_SWARM=true
    INSTALL_TRAEFIK=false
    ;;
  3)
    INSTALL_DOCKER=true
    INSTALL_SWARM=true
    INSTALL_TRAEFIK=true
    ;;
  *)
    echo "❌ Choix invalide. Veuillez relancer le script."
    exit 1
    ;;
esac

echo ""
echo "📝 Récapitulatif de l'installation :"
[ "$INSTALL_DOCKER" = true ] && echo "✔️ Docker"
[ "$INSTALL_SWARM" = true ] && echo "✔️ Docker Swarm"
[ "$INSTALL_TRAEFIK" = true ] && echo "✔️ Traefik + HTTPS + Auth"
echo ""

### === INSTALLATION DE DOCKER === ###
if [ "$INSTALL_DOCKER" = true ]; then
  echo "[1/6] Suppression d'éventuels anciens paquets Docker..."
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y $pkg || true
  done

  echo "[2/6] Installation des dépendances et ajout de la clé GPG Docker..."
  apt-get update
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo "[3/6] Ajout du dépôt Docker..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

  apt-get update

  echo "[4/6] Installation de Docker..."
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  echo "[5/6] Ajout de l'utilisateur courant au groupe docker..."
  REAL_USER="${SUDO_USER:-$USER}"
  usermod -aG docker "$REAL_USER"
  echo "ℹ️ L'utilisateur $REAL_USER a été ajouté au groupe docker."
fi

### === INIT SWARM === ###
if [ "$INSTALL_SWARM" = true ]; then
  echo "[6/6] Initialisation de Docker Swarm..."
  docker swarm init || echo "ℹ️ Swarm déjà initialisé."
fi

### === TRAEFIK === ###
if [ "$INSTALL_TRAEFIK" = true ]; then
  echo "[🔧] Installation de apache2-utils pour htpasswd..."
  apt-get install -y apache2-utils

  read -p "Nom de domaine (hostname) pour Traefik : " HOSTNAME
  read -p "Nom d'utilisateur pour l'accès sécurisé : " HTPASS_USER
  read -s -p "Mot de passe pour $HTPASS_USER : " HTPASS_PASS
  echo ""
  read -p "Adresse email pour Let's Encrypt (ex: admin@example.com) : " LETSENCRYPT_EMAIL

  HTPASS_ENCODED=$(htpasswd -nbB "$HTPASS_USER" "$HTPASS_PASS" | sed -e 's/\\/\\\\/g' -e 's/\$/\$\$/g')

  echo "📁 Création des dossiers dans /data/traefik..."
  mkdir -p /data/traefik/{ssl,letsencrypt,certs}
  chown -R 1000:1000 /data

  cat <<EOF > /data/traefik/certs/traefik-certs.yml
tls:
  options:
    default:
      minVersion: VersionTLS12
      cipherSuites:
        - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
EOF

  cat <<EOF > /data/traefik/docker-compose.yml
version: '3.4'

services:
  traefik:
    image: traefik:v2.11.3
    ports:
      - 80:80
      - 443:443
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - traefik.enable=true
        - traefik.docker.network=traefik-public
        - traefik.constraint-label=traefik-public
        - "traefik.http.middlewares.admin-auth.basicauth.users=$HTPASS_ENCODED"
        - traefik.http.middlewares.filtrage-https.chain.middlewares=admin-auth
        - traefik.http.middlewares.https-redirect.redirectscheme.scheme=https
        - traefik.http.middlewares.https-redirect.redirectscheme.permanent=true
        - traefik.http.routers.traefik-public-http.rule=Host(\`$HOSTNAME\`)
        - traefik.http.routers.traefik-public-http.entrypoints=http
        - traefik.http.routers.traefik-public-http.middlewares=https-redirect
        - traefik.http.routers.traefik-public-https.rule=Host(\`$HOSTNAME\`)
        - traefik.http.routers.traefik-public-https.entrypoints=https
        - traefik.http.routers.traefik-public-https.tls=true
        - traefik.http.routers.traefik-public-https.service=api@internal
        - traefik.http.routers.traefik-public-https.tls.certresolver=letsencrypt
        - traefik.http.routers.traefik-public-https.middlewares=filtrage-https
        - traefik.http.services.traefik-public.loadbalancer.server.port=8080
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /data/traefik/ssl:/etc/certs/
      - /data/traefik/letsencrypt:/letsencrypt
      - /data/traefik/certs/traefik-certs.yml:/etc/traefik/dynamic/certs-traefik.yaml
    command:
      - --providers.docker
      - --providers.file.directory=/etc/traefik/dynamic
      - --providers.docker.constraints=Label(\`traefik.constraint-label\`, \`traefik-public\`)
      - --providers.docker.exposedbydefault=false
      - --providers.docker.swarmmode
      - --entrypoints.http.address=:80
      - --entrypoints.https.address=:443
      - --accesslog
      - --log
      - --api
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --certificatesresolvers.letsencrypt.acme.email=$LETSENCRYPT_EMAIL
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
    networks:
      - traefik-public
      - public-web

networks:
  public-web:
    driver: overlay
  traefik-public:
    external: true
EOF

  echo "🔄 Création du réseau traefik-public..."
  if ! docker network inspect traefik-public >/dev/null 2>&1; then
    docker network create \
      --driver=overlay \
      --attachable \
      --subnet=10.123.96.0/20 \
      --ip-range=10.123.96.0/20 \
      traefik-public
    echo "✅ Réseau 'traefik-public' créé."
  else
    echo "ℹ️ Réseau 'traefik-public' déjà existant."
  fi

  echo "🚀 Déploiement de la stack Traefik..."
  docker stack deploy -c /data/traefik/docker-compose.yml traefik

  echo "✅ Stack Traefik déployée avec succès sur $HOSTNAME"
fi
