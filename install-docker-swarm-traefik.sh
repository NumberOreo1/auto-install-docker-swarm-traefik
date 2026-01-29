#!/bin/bash

# Force execution with sudo
if [[ $EUID -ne 0 ]]; then
  echo "[ERR] This script must be run with sudo: sudo $0"
  exit 1
fi

set -e

### === INTERACTIVE MENU === ###
echo "What would you like to install?"
echo "1) Install only Docker"
echo "2) Install Docker + Swarm"
echo "3) Install Docker + Swarm + Traefik"
read -p "[*] Enter the number of your choice [1-3]: " CHOICE

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
    echo "[ERR] Invalid choice. Please restart the script."
    exit 1
    ;;
esac

echo ""
echo "[*] Installation summary:"
[ "$INSTALL_DOCKER" = true ] && echo "[OK] Docker"
[ "$INSTALL_SWARM" = true ] && echo "[OK] Docker Swarm"
[ "$INSTALL_TRAEFIK" = true ] && echo "[OK] Traefik + HTTPS + Auth"
echo ""

### === INSTALLATION OF DOCKER === ###
if [ "$INSTALL_DOCKER" = true ]; then
  echo "[1/6] Removing any existing Docker packages..."
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y $pkg || true
  done

  echo "[2/6] Installing dependencies and adding Docker GPG key..."
  apt-get update
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo "[3/6] Adding Docker repository..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

  apt-get update

  echo "[4/6] Installing Docker..."
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  echo "[5/6] Adding the current user to the Docker group..."
  REAL_USER="${SUDO_USER:-$USER}"
  usermod -aG docker "$REAL_USER"
  echo "[INFO] User $REAL_USER has been added to the Docker group."
fi

### === INIT SWARM === ###
if [ "$INSTALL_SWARM" = true ]; then
  echo "[6/6] Initializing Docker Swarm..."
  docker swarm init || echo "[INFO] Swarm already initialized."
fi

### === TRAEFIK === ###
if [ "$INSTALL_TRAEFIK" = true ]; then
  echo "[*] Installing apache2-utils for htpasswd..."
  apt-get install -y apache2-utils

  read -p "Domain name (hostname) for Traefik: " HOSTNAME
  read -p "Username for secure access: " HTPASS_USER
  read -s -p "Password for $HTPASS_USER: " HTPASS_PASS
  echo ""
  read -p "Email address for Let's Encrypt (e.g., admin@example.com): " LETSENCRYPT_EMAIL

  HTPASS_ENCODED=$(htpasswd -nbB "$HTPASS_USER" "$HTPASS_PASS" | sed -e 's/\\/\\\\/g' -e 's/\$/\$\$/g')

  echo "[*] Creating folders in /data/traefik..."
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
    image: traefik:v3.6.7
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
      - --providers.swarm=true
      - --providers.swarm.constraints=Label(\`traefik.constraint-label\`, \`traefik-public\`)
      - --providers.docker.exposedbydefault=false
      - --providers.docker=false
      - --providers.file.directory=/etc/traefik/dynamic
      - --entrypoints.http.address=:80
      - --entrypoints.http.forwardedHeaders.insecure=true
      - --entrypoints.https.address=:443
      - --entrypoints.https.forwardedHeaders.insecure=true
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

  echo "[*] Creating the traefik-public network..."
  if ! docker network inspect traefik-public >/dev/null 2>&1; then
    docker network create \
      --driver=overlay \
      --attachable \
      --subnet=10.123.96.0/20 \
      --ip-range=10.123.96.0/20 \
      traefik-public
    echo "[OK] 'traefik-public' network created."
  else
    echo "[INFO] 'traefik-public' network already exists."
  fi

  echo "[*] Deploying the Traefik stack..."
  docker stack deploy -c /data/traefik/docker-compose.yml traefik

  echo "[OK] Traefik stack successfully deployed on $HOSTNAME"
fi
