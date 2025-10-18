#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
INSTALL_DIR="/opt/remnawave/nginx"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
NGINX_CONF_FILE="$INSTALL_DIR/nginx.conf"
KEY_FILE="$INSTALL_DIR/privkey.key"
CHAIN_FILE="$INSTALL_DIR/fullchain.pem"
ACME_SH_PATH="$HOME/.acme.sh/acme.sh"

# --- Colors for better output ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'

# --- Helper Functions ---
info() { echo -e "${C_CYAN}> $1${C_RESET}"; }
success() { echo -e "${C_GREEN}✓ $1${C_RESET}"; }
error() { echo -e "${C_RED}✗ $1${C_RESET}"; exit 1; }
ask() {
    local prompt="$1"
    local var_name="$2"
    read -p "$(echo -e "${C_YELLOW}$prompt${C_RESET}")" "$var_name"
}

# --- Prerequisite Installers ---
install_acme_sh() {
    info "Installing acme.sh..."
    if curl https://get.acme.sh | sh -s email="$EMAIL"; then
        success "acme.sh installed. You may need to run 'source ~/.bashrc' or restart your terminal."
    else
        error "acme.sh installation failed."
    fi
}

install_docker() {
    info "Installing Docker..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    if apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        success "Docker and Docker Compose installed successfully."
    else
        error "Docker installation failed."
    fi
}

check_and_install_prerequisites() {
    info "Checking prerequisites..."
    if ! command -v docker &> /dev/null; then
        ask "Docker is not found. Would you like to install it now? (y/n): " INSTALL_DOCKER
        if [[ "$INSTALL_DOCKER" == "y" ]]; then
            install_docker
        else
            error "Docker is required to proceed."
        fi
    fi

    if [ ! -f "$ACME_SH_PATH" ]; then
        ask "acme.sh is not found. Would you like to install it now? (y/n): " INSTALL_ACME
        if [[ "$INSTALL_ACME" == "y" ]]; then
            while [[ -z "$EMAIL" ]]; do
                ask "Enter your email for acme.sh installation: " EMAIL
            done
            install_acme_sh
            # The script needs to be sourced for the path to be available immediately
            source "$HOME/.bashrc" || source "$HOME/.profile" || source "$HOME/.zshrc"
        else
            error "acme.sh is required to proceed."
        fi
    fi
    success "All prerequisites are satisfied."
}

# --- Main Logic ---
get_user_input() {
    info "Gathering required information..."
    if [[ -z "$EMAIL" ]]; then
        while [[ -z "$EMAIL" ]]; do
            ask "Enter your email for Let's Encrypt registration: " EMAIL
        done
    fi

    echo -e "${C_YELLOW}Is this for a single domain or multiple domains?${C_RESET}"
    echo "  [1] Single Domain"
    echo "  [2] Multiple Domains"
    while true; do
        ask "Enter your choice [1-2]: " choice
        case "$choice" in
            1)
                ask "Enter your domain name (e.g., example.com): " PRIMARY_DOMAIN
                DOMAINS=("$PRIMARY_DOMAIN")
                break
                ;;
            2)
                ask "Enter the primary domain name (e.g., www.example.com): " PRIMARY_DOMAIN
                DOMAINS=("$PRIMARY_DOMAIN")
                info "Now enter your other domains. Press [Enter] on an empty line when you're done."
                while true; do
                    ask "  > Add domain: " NEXT_DOMAIN
                    if [ -z "$NEXT_DOMAIN" ]; then break; fi
                    DOMAINS+=("$NEXT_DOMAIN")
                done
                break
                ;;
            *) echo -e "${C_RED}Invalid choice.${C_RESET}";;
        esac
    done

    echo -e "\n${C_YELLOW}What action would you like to perform?${C_RESET}"
    echo "  [1] First Time Setup (Issue a new certificate)"
    echo "  [2] Renew Existing Certificate"
    while true; do
        ask "Enter your choice [1-2]: " choice
        case "$choice" in
            1) ACTION="new"; break;;
            2) ACTION="renew"; break;;
            *) echo -e "${C_RED}Invalid choice.${C_RESET}";;
        esac
    done
}

create_config_files() {
    info "Checking for configuration files in $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"

    if [ ! -f "$COMPOSE_FILE" ]; then
        info "docker-compose.yml not found. Creating it..."
        cat << EOF > "$COMPOSE_FILE"
services:
    remnawave-nginx:
        image: nginx:1.28
        container_name: remnawave-nginx
        hostname: remnawave-nginx
        volumes:
            - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
            - ./fullchain.pem:/etc/nginx/ssl/fullchain.pem:ro
            - ./privkey.key:/etc/nginx/ssl/privkey.key:ro
        restart: always
        ports:
            - '0.0.0.0:443:443'
        networks:
            - remnawave-network

networks:
    remnawave-network:
        name: remnawave-network
        driver: bridge
        external: true
EOF
        success "docker-compose.yml created."
    else
        info "docker-compose.yml already exists. Skipping creation."
    fi

    if [ ! -f "$NGINX_CONF_FILE" ]; then
        info "nginx.conf not found. Creating it..."
        SERVER_NAMES=$(IFS=$' '; echo "${DOMAINS[*]}")
        cat << EOF > "$NGINX_CONF_FILE"
upstream remnawave {
    server remnawave:3000;
}
server {
    server_name $SERVER_NAMES;
    listen 443 ssl reuseport;
    listen [::]:443 ssl reuseport;
    http2 on;
    location / {
        proxy_http_version 1.1;
        proxy_pass http://remnawave;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    ssl_certificate "/etc/nginx/ssl/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/privkey.key";
}
server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;
    ssl_reject_handshake on;
}
EOF
        success "nginx.conf created for domain(s): $SERVER_NAMES"
    else
        info "nginx.conf already exists. Skipping creation."
    fi
}

manage_certificate() {
    info "Setting Let's Encrypt as the default CA..."
    "$ACME_SH_PATH" --set-default-ca --server letsencrypt

    info "Registering account with email: $EMAIL"
    "$ACME_SH_PATH" --register-account -m "$EMAIL"

    DOMAIN_ARGS=""
    for domain in "${DOMAINS[@]}"; do
        DOMAIN_ARGS+=" -d $domain"
    done

    ACME_CMD="$ACME_SH_PATH --issue --standalone $DOMAIN_ARGS --key-file $KEY_FILE --fullchain-file $CHAIN_FILE"

    if [ "$(docker ps -q -f name=remnawave-nginx)" ]; then
        info "Temporarily stopping running Nginx container..."
        docker compose -f "$COMPOSE_FILE" stop
    fi

    if [ "$ACTION" == "renew" ]; then
        ACME_CMD+=" --force"
    fi

    info "Running acme.sh to get the certificate..."
    if ! eval "$ACME_CMD"; then
        error "Certificate issuance failed. Please check logs."
    fi
    success "Certificate has been successfully issued/renewed!"
}

start_server() {
    info "Starting the Nginx container..."
    docker compose -f "$COMPOSE_FILE" up -d
    success "Nginx container is starting in the background."
    info "You can check the logs with: docker compose -f $COMPOSE_FILE logs -f"
}

# --- Script Execution ---
main() {
    check_and_install_prerequisites
    get_user_input
    create_config_files
    manage_certificate
    start_server

    echo -e "\n\n${C_GREEN}========================================="
    success "Setup is complete!"
    echo -e "=========================================${C_RESET}"
}

main