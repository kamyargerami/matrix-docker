#!/bin/bash

# --- Color Definitions ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Config path ---
SYNAPSE_CONF="/var/lib/docker/volumes/matrix_synapse_data/_data/homeserver.yaml"
NGINX_CONF="/var/lib/docker/volumes/matrix_nginx_conf/_data/default.conf"
COTURN_CONF="/var/lib/docker/volumes/matrix_coturn/_data/turnserver.conf"
ELEMENT_CONF="/var/lib/docker/volumes/matrix_element/_data/config.json"

echo -e "${CYAN}🚀 Starting Matrix Deployment for $DOMAIN ($SERVER_IP)...${NC}"

cd matrix || exit
cp .env.example .env
source .env

DOMAIN=$1
SERVER_IP=$2
PG_PASS=$3

# 1. Write params to .env file
echo -e "${GREEN}--- Configuring .env file ---${NC}"
sed -i "s|DOMAIN=example.com|DOMAIN=$DOMAIN|g" .env
sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$PG_PASS|g" .env

# Usage: sudo ./setup_matrix.sh <domain> <server_ip> <postgres_pass>
if [ -z "$DOMAIN" ] || [ -z "$SERVER_IP" ] || [ -z "$PG_PASS" ]; then
    echo -e "${RED}Error: Missing parameters.${NC}"
    echo "Usage: sudo $0 <your-domain.com> <your-server-ip> <postgres-password>"
    exit 1
fi

# 2. Prevent Reinstall

if [ -f "$SYNAPSE_CONF" ]; then
    echo -e "${RED}🛑 Error: An existing installation was detected at $SYNAPSE_CONF${NC}"
    echo -e "${YELLOW}To reinstall, please remove the docker volumes first: docker-compose down -v${NC}"
    exit 1
fi

# 3. Generate Initial Synapse Config (Defaults to SQLite)
echo -e "${YELLOW}--- Generating initial Synapse configuration ---${NC}"
docker run --rm \
    -v "matrix_synapse_data:/data" \
    -e SYNAPSE_SERVER_NAME=$DOMAIN \
    -e SYNAPSE_REPORT_STATS=yes \
    matrixdotorg/synapse:$SYNAPSE_VERSION generate

# 4. Initial Run to initialize volumes/configs
echo -e "${YELLOW}--- Initializing docker volumes ---${NC}"
docker-compose up -d
echo -e "${YELLOW}--- Wait 20 seconds ---${NC}"
sleep 20
docker-compose stop

# 5. Generate Secrets
echo -e "${GREEN}--- Generating Secure Keys ---${NC}"
COTURN_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
CLI_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)

# 6. Patch Nginx Configuration
echo -e "${GREEN}--- Patching Nginx config ---${NC}"
sed -i '/^}/i \
\n\
    location /.well-known/matrix/server {\n\
        access_log off;\n\
        add_header Access-Control-Allow-Origin *;\n\
        default_type application/json;\n\
        return 200 '\''{"m.server": "matrix.example.com:443"}'\'';\n\
    }\n\
\n\
    location /.well-known/matrix/client {\n\
        access_log off;\n\
        add_header Access-Control-Allow-Origin *;\n\
        default_type application/json;\n\
        return 200 '\''{"m.homeserver": {"base_url": "https://matrix.example.com"}}'\'';\n\
    }\n' $NGINX_CONF
sudo sed -i "s|example.com|$DOMAIN|g" $NGINX_CONF

# 7. Patch Coturn Configuration
echo -e "${GREEN}--- Patching Coturn config ---${NC}"
sudo bash -c "cat <<EOF > $COTURN_CONF
use-auth-secret
static-auth-secret=$COTURN_SECRET
realm=matrix.$DOMAIN
listening-port=3478
tls-listening-port=5349
min-port=49160
max-port=49200
verbose
allow-loopback-peers
cli-password=$CLI_PASS
external-ip=$SERVER_IP
EOF"

# 8. Patch Synapse Configuration (Switching SQLite to Postgres + adding TURN)
echo -e "${GREEN}--- Switching Synapse to Postgres & adding TURN ---${NC}"

# Remove the default SQLite database block (from 'database:' until the next top-level key)
sudo sed -i '/database:/,/^[^ ]/ { /^database:/d; /^  /d; }' $SYNAPSE_CONF

# Append Postgres and TURN config
sudo bash -c "cat <<EOF >> $SYNAPSE_CONF

database:
  name: psycopg2
  txn_limit: 10000
  args:
    user: synapse
    password: $PG_PASS
    database: synapse
    host: synapse_db
    port: 5432
    cp_min: 5
    cp_max: 10

turn_shared_secret: \"$COTURN_SECRET\"
turn_uris:
    - \"turn:matrix.$DOMAIN?transport=udp\"
    - \"turn:matrix.$DOMAIN?transport=tcp\"
    - \"turns:matrix.$DOMAIN?transport=udp\"
    - \"turns:matrix.$DOMAIN?transport=tcp\"

enable_registration: true
enable_registration_without_verification: true
EOF"

# 9. Patch Element Configuration
echo -e "${GREEN}--- Patching Element Web config ---${NC}"
sudo sed -i "s|https://matrix-client.matrix.org|https://matrix.$DOMAIN|g" $ELEMENT_CONF
sudo sed -i "s|\"server_name\": \"matrix.org\"|\"server_name\": \"$DOMAIN\"|g" $ELEMENT_CONF

# 10. Final Start
echo -e "${CYAN}--- Finalizing Deployment ---${NC}"
docker-compose up -d

echo -e "\n-------------------------------------------------------"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "Main Domain: ${YELLOW}$DOMAIN${NC}"
echo -e "Element Web: ${CYAN}https://web.$DOMAIN${NC}"
echo -e "Homeserver:  ${CYAN}https://matrix.$DOMAIN${NC}"
echo -e "Logs:  ${YELLOW}docker-compose -f matrix/docker-compose.yml logs -f${NC}"
echo -e "-------------------------------------------------------\n"
