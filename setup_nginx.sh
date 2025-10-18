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
    apt-get update && apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error "Docker installation failed."
    success "Docker and Docker Compose installed successfully."
}
check_and_install_prerequisites() {
    info "Checking prerequisites..."
    if ! command -v docker &> /dev/null; then
        ask "Docker is not found. Would you like to install it now? (y/n): " INSTALL_DOCKER
        if [[ "$INSTALL_DOCKER" == "y" ]]; then install_docker; else error "Docker is required to proceed."; fi
    fi
    if [ ! -f "$ACME_SH_PATH" ]; then
        ask "acme.sh is not found. Would you like to install it now? (y/n): " INSTALL_ACME
        if [[ "$INSTALL_ACME" == "y" ]]; then
            while [[ -z "$EMAIL" ]]; do ask "Enter your email for acme.sh installation: " EMAIL; done
            install_acme_sh
            source "$HOME/.bashrc" || source "$HOME/.profile" || source "$HOME/.zshrc"
        else
            error "acme.sh is required to proceed."
        fi
    fi
    success "All prerequisites are satisfied."
}

# --- Main Logic ---
get_user_input() {
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

    info "\nGathering required information..."
    if [[ -z "$EMAIL" ]]; then
        while [[ -z "$EMAIL" ]]; do ask "Enter your email for Let's Encrypt registration: " EMAIL; done
    fi

    ask "Do you have a Remnawave Subscription Page setup? (y/n): " HAS_SUB_PAGE

    if [[ "$HAS_SUB_PAGE" == "y" ]]; then
        info "Please provide the domains for the Panel and Subscription Page."
        while [[ -z "$PANEL_DOMAIN" ]]; do ask "Enter the domain for the PANEL (e.g., panel.example.com): " PANEL_DOMAIN; done
        while [[ -z "$SUB_DOMAIN" ]]; do ask "Enter the domain for the SUBSCRIPTION PAGE (e.g., sub.example.com): " SUB_DOMAIN; done
        DOMAINS=("$PANEL_DOMAIN" "$SUB_DOMAIN")
    else
        info "Please provide the domain(s) for the Remnawave Panel."
        while [[ -z "$PRIMARY_DOMAIN" ]]; do ask "Enter the primary domain name (e.g., panel.example.com): " PRIMARY_DOMAIN; done
        DOMAINS=("$PRIMARY_DOMAIN")
        ask "Do you have additional domains for the panel? (y/n): " ADD_DOMAINS
        if [[ "$ADD_DOMAINS" == "y" ]]; then
            info "Enter your other domains. Press [Enter] on an empty line when you're done."
            while true; do
                ask "  > Add domain: " NEXT_DOMAIN
                if [ -z "$NEXT_DOMAIN" ]; then break; fi
                DOMAINS+=("$NEXT_DOMAIN")
            done
        fi
    fi
}

create_config_files() {
    info "Preparing configuration files in $INSTALL_DIR..."
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
    fi

    info "Generating nginx.conf based on your selections..."
    rm -f "$NGINX_CONF_FILE"

    if [[ "$HAS_SUB_PAGE" == "y" ]]; then
        # *** CORRECTED: Using your full, detailed template for Panel + Sub Page ***
        cat << EOF > "$NGINX_CONF_FILE"
upstream remnawave {
    server remnawave:3000;
}

upstream remnawave-subscription-page {
    server remnawave-subscription-page:3010;
}

server {
    server_name $PANEL_DOMAIN;

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

    ssl_protocols             TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets       off;
    ssl_certificate "/etc/nginx/ssl/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/privkey.key";
    ssl_trusted_certificate "/etc/nginx/ssl/fullchain.pem";
    ssl_stapling              on;
    ssl_stapling_verify       on;
    resolver                  1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 208.67.222.222 208.67.220.220 valid=60s;
    resolver_timeout          2s;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types application/atom+xml application/geo+json application/javascript application/x-javascript application/json application/ld+json application/manifest+json application/rdf+xml application/rss+xml application/xhtml+xml application/xml font/eot font/otf font/ttf image/svg+xml text/css text/javascript text/plain text/xml;
}

server {
    server_name $SUB_DOMAIN;

    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;

    location / {
        proxy_http_version 1.1;
        proxy_pass http://remnawave-subscription-page;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    ssl_protocols             TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets       off;
    ssl_certificate "/etc/nginx/ssl/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/privkey.key";
    ssl_trusted_certificate "/etc/nginx/ssl/fullchain.pem";
    ssl_stapling              on;
    ssl_stapling_verify       on;
    resolver                  1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 208.67.222.222 208.67.220.220 valid=60s;
    resolver_timeout          2s;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types application/atom+xml application/geo+json application/javascript application/x-javascript application/json application/ld+json application/manifest+json application/rdf+xml application/rss+xml application/xhtml+xml application/xml font/eot font/otf font/ttf image/svg+xml text/css text/javascript text/plain text/xml;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;
    ssl_reject_handshake on;
}
EOF
        success "nginx.conf created for Panel and Subscription Page."
    else
        # *** CORRECTED: Using your full, detailed template for Panel Only ***
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

    ssl_protocols             TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets       off;
    ssl_certificate "/etc/nginx/ssl/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/privkey.key";
    ssl_trusted_certificate "/etc/nginx/ssl/fullchain.pem";
    ssl_stapling              on;
    ssl_stapling_verify       on;
    resolver                  1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 208.67.222.222 208.67.220.220 valid=60s;
    resolver_timeout          2s;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types application/atom+xml application/geo+json application/javascript application/x-javascript application/json application/ld+json application/manifest+json application/rdf+xml application/rss+xml application/xhtml+xml application/xml font/eot font/otf font/ttf image/svg+xml text/css text/javascript text/plain text/xml;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;
    ssl_reject_handshake on;
}
EOF
        success "nginx.conf created for Panel domain(s)."
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
    if [ "$ACTION" == "renew" ]; then
        ACME_CMD+=" --force"
    fi
    if [ -f "$COMPOSE_FILE" ] && [ "$(docker ps -q -f name=remnawave-nginx)" ]; then
        info "Temporarily stopping Nginx container to free up port 80..."
        docker compose -f "$COMPOSE_FILE" stop
    fi
    info "Running acme.sh command..."
    echo "  > $ACME_CMD"
    if ! eval "$ACME_CMD"; then
        if [ -f "$COMPOSE_FILE" ]; then start_server; fi
        error "Certificate issuance/renewal failed. Please check logs from acme.sh."
    fi
    success "Certificate has been successfully issued/renewed!"
}

start_server() {
    if [ -f "$COMPOSE_FILE" ]; then
        info "Starting the Nginx container..."
        docker compose -f "$COMPOSE_FILE" up -d
        success "Nginx container is starting."
        info "You can check the logs with: docker compose -f $COMPOSE_FILE logs -f"
    fi
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