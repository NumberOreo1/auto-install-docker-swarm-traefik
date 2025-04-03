# 🚀 Auto Install Docker Swarm + Traefik

Ce script Bash interactif permet d’installer rapidement un environnement Docker complet sur un serveur basé sur Debian (Debian, Ubuntu, etc.). Il propose plusieurs niveaux d'installation, allant de Docker seul à un reverse proxy complet avec **Traefik**, **HTTPS**, et **authentification sécurisée**.

---

## 🧰 Fonctionnalités

### 🔐 Droits root
- Exécution forcée avec `sudo` pour garantir les droits nécessaires.

### 📋 Menu interactif
Choisissez le niveau d’installation au démarrage :
- Docker uniquement
- Docker + Docker Swarm
- Docker + Swarm + Traefik avec HTTPS et authentification

### 🐳 Installation de Docker
- Installation propre et à jour de Docker
- Suppression des anciens paquets obsolètes

### 🌐 Initialisation de Docker Swarm
- Configuration du mode Swarm (single node ou cluster ready)

### ⚙️ Déploiement automatique de Traefik (mode Swarm)
- Reverse proxy intelligent
- Certificats SSL Let's Encrypt
- Authentification HTTP basic (`htpasswd`)
- Configuration dynamique via fichiers YAML

### 🛠️ Structure automatique générée
- Dossiers créés :
  ```bash
  /data/traefik/
  ├── certs/
  │   └── traefik-certs.yml
  ├── letsencrypt/
  │   └── acme.json (généré automatiquement)
  ├── ssl/
  └── docker-compose.yml
  ```

---

## 🔒 Sécurité

- Génération d’un mot de passe chiffré (`htpasswd`) via `apache2-utils`
- Middleware Traefik configuré pour protéger l’accès à l’interface web
- Configuration TLS renforcée :
  - TLS 1.2 minimum
  - Suites de chiffrement recommandées

---

## ✅ Prérequis

- Serveur Debian/Ubuntu à jour
- `sudo` activé
- Ports **80** et **443** ouverts

---

## 💡 Utilisation

```bash
git clone https://github.com/NumberOreo1/auto-install-docker-swarm-traefik.git
cd auto-install-docker-swarm-traefik
sudo ./install-docker-swarm-traefik.sh
```

---

