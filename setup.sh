#!/bin/bash

# Function to check successful command execution
check_success() {
  if [ $? -ne 0 ]; then
    echo "❌ Error executing $1"
    echo "Installation aborted. Please fix the errors and try again."
    exit 1
  fi
}

# Function to display progress
show_progress() {
  echo ""
  echo "========================================================"
  echo "   $1"
  echo "========================================================"
  echo ""
}

# Main installation function
main() {
  show_progress "🚀 Starting installation of n8n, Flowise, and Caddy. DB Qdrant and PetgreSQL. gpt2giga for GigaChat"
  
  # Check administrator rights
  if [ "$EUID" -ne 0 ]; then
    if ! sudo -n true 2>/dev/null; then
      echo "Administrator rights are required for installation"
      echo "Please enter the administrator password when prompted"
    fi
  fi
  
  # Request user data
  echo "For installation, you need to specify a domain name and email address."
  
  # Request domain name
  read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME
  while [[ -z "$DOMAIN_NAME" ]]; do
    echo "Domain name cannot be empty"
    read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME
  done
  
  # Request email address
  read -p "Enter your email (will be used for n8n login): " USER_EMAIL
  while [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
    echo "Enter a valid email address"
    read -p "Enter your email (will be used for n8n login): " USER_EMAIL
  done
  
  # Request timezone
  DEFAULT_TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
  read -p "Enter your timezone (default: $DEFAULT_TIMEZONE): " GENERIC_TIMEZONE
  GENERIC_TIMEZONE=${GENERIC_TIMEZONE:-$DEFAULT_TIMEZONE}

  # Request GigaChat_API
  read -p "Enter your GigaChat_API (see on https://developers.sber.ru/portal/products/gigachat-api): " GIGACHAT_API
  while [[ -z "$GIGACHAT_API" ]]; do
    echo "GigaChat API cannot be empty"
    read -p "Enter your GigaChat_API (see on https://developers.sber.ru/portal/products/gigachat-api): " GIGACHAT_API
  done
  
  # Create setup-files directory if it doesn't exist
  if [ ! -d "setup-files" ]; then
    mkdir -p setup-files
    check_success "creating setup-files directory"
  fi
  
  # Set execution permissions for all scripts
  chmod +x setup-files/*.sh 2>/dev/null || true
  
  # Step 1: System update
  show_progress "Step 1/7: System update"
  ./setup-files/01-update-system.sh
  check_success "system update"
  
  # Step 2: Docker installation
  show_progress "Step 2/7: Docker installation"
  ./setup-files/02-install-docker.sh
  check_success "Docker installation"
  
  # Step 3: Directory setup
  show_progress "Step 3/7: Directory setup"
  ./setup-files/03-setup-directories.sh
  check_success "directory setup"
  
  # Step 4: Secret key generation
  show_progress "Step 4/7: Secret key generation"
  ./setup-files/04-generate-secrets.sh "$USER_EMAIL" "$DOMAIN_NAME" "$GENERIC_TIMEZONE" "$GIGACHAT_API"
  check_success "secret key generation"
  
  # Step 5: Template creation
  show_progress "Step 5/7: Configuration file creation"
  ./setup-files/05-create-templates.sh "$DOMAIN_NAME"
  check_success "configuration file creation"
  
  # Step 6: Firewall setup
  show_progress "Step 6/7: Firewall setup"
  ./setup-files/06-setup-firewall.sh
  check_success "firewall setup"
  
  # Step 7: Service launch
  show_progress "Step 7/7: Service launch"
  ./setup-files/07-start-services.sh
  check_success "service launch"

  # Step 8: Models download
  
  # Load generated passwords
  N8N_PASSWORD=""
  FLOWISE_PASSWORD=""
#  POSTGRES_PASSWORD=""
  if [ -f "./setup-files/passwords.txt" ]; then
    source ./setup-files/passwords.txt
  fi
  
  # Installation successfully completed
  show_progress "✅ Installation successfully completed!"
  
  echo "n8n is available at: https://n8n.${DOMAIN_NAME}"
  echo "Flowise is available at: https://flowise.${DOMAIN_NAME}"
  echo ""
  echo "Login credentials for n8n:"
  echo "Email: ${USER_EMAIL}"
  echo "Password: ${N8N_PASSWORD:-<check the .env file>}"
  echo ""
  echo "Login credentials for Flowise:"
  echo "Username: admin"
  echo "Password: ${FLOWISE_PASSWORD:-<check the .env file>}"
  echo ""
  echo "Postgres:"
  echo "Username: postgres"
  echo "Database: postgres"
  echo "Host: postgres"
  echo "Password: ${POSTGRES_PASSWORD:-<check the .env file>}"
  echo ""
  echo "Ollama without any password and keys: base URL=> http://ollama:11434"
  echo "Qdrant without any password and keys: base URL=> http://qdrant:6333"
  echo ""
  echo "Please note that for the domain name to work, you need to configure DNS records"
  echo "pointing to the IP address of this server."
  echo ""
  echo "To edit the configuration, use the following files:"
  echo "- n8n-docker-compose.yaml (n8n and Caddy configuration)"
  echo "- flowise-docker-compose.yaml (Flowise configuration)"
  echo "- .env (environment variables for all services)"
  echo "- Caddyfile (reverse proxy settings)"
  echo ""
  echo "To restart services, execute the commands:"
  echo "docker compose -f n8n-docker-compose.yaml restart"
  echo "docker compose -f flowise-docker-compose.yaml restart"
}

# Run main function

main 