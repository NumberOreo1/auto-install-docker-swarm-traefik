# Docker, Swarm, and Traefik Installation Script

This bash script provides an easy way to install Docker, Docker Swarm, and Traefik (with HTTPS and basic authentication) on your system. It offers an interactive menu for different installation configurations based on your needs.

## Features

- **Docker Installation**: Installs Docker along with required dependencies.
- **Docker Swarm Initialization**: Option to initialize Docker Swarm.
- **Traefik Setup**: Option to set up Traefik with SSL certificates and basic authentication for secure access.

## Prerequisites

- A machine running a Debian-based OS (such as Ubuntu).
- **Sudo privileges** to install and configure system-level software.
- An active internet connection for downloading dependencies and Docker images.

## Installation Options

The script allows you to choose between 3 different installation setups:

1. **Install only Docker**: Installs Docker only (without Swarm or Traefik).
2. **Install Docker + Swarm**: Installs Docker and initializes Docker Swarm.
3. **Install Docker + Swarm + Traefik**: Installs Docker, initializes Docker Swarm, and sets up Traefik with SSL and authentication.

## Usage

### Step 1: Clone this Repository

Clone the repository to your local machine:

```bash
git clone https://github.com/NumberOreo1/auto-install-docker-swarm-traefik.git
cd docker-swarm-traefik-installation
```

### Step 2: Run the Script

Make sure to run the script with `sudo` privileges. The script will prompt you with an interactive menu to choose the installation options.

```bash
sudo bash install.sh
```

### Step 3: Follow the On-Screen Instructions

- The script will guide you through the process of selecting which components to install.
- If you select to install **Traefik**, the script will ask you for the following details:
  - Domain name (hostname) for Traefik.
  - Username for HTTP basic authentication.
  - Password for HTTP basic authentication.
  - Email address for Let's Encrypt SSL certificates.

### Step 4: Access Traefik Dashboard

After the script finishes running, you can access the Traefik dashboard by visiting the domain you configured in your browser. The Traefik dashboard will be secured with basic authentication.

## Configuration

If you choose to install **Traefik**, the script will:

- Generate SSL certificates using Let's Encrypt.
- Set up basic authentication to protect the Traefik dashboard.
- Deploy Traefik in Docker Swarm as a stack.

## Troubleshooting

- Ensure you are running the script with `sudo` privileges.
- If Docker Swarm is already initialized, the script will skip initializing it again.
- If the **traefik-public** network already exists, the script will skip its creation.
  
