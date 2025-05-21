#!/bin/bash

# === Styling ===
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}Starting Pipe Network PoP Node Setup...${NC}"

# === Step 1: Install Dependencies ===
echo -e "${CYAN}Installing dependencies...${NC}"
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y wget curl libssl-dev ca-certificates ufw jq tar gzip net-tools git

# === Step 1.1: Optimize Network Settings ===
echo -e "${CYAN}Optimizing network settings for PoP node...${NC}"
sudo bash -c 'cat > /etc/sysctl.d/99-popcache.conf << EOL
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.core.wmem_max = 16777216
net.core.rmem_max = 16777216
EOL'
sudo sysctl -p /etc/sysctl.d/99-popcache.conf

# === Step 1.2: Configure UFW ===
echo -e "${CYAN}Checking UFW firewall...${NC}"
if ! sudo ufw status | grep -q "Status: active"; then
  echo -e "${YELLOW}UFW is not active. Configuring...${NC}"
  sudo ufw allow 443/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow OpenSSH
  sudo ufw --force enable
else
  echo -e "${CYAN}UFW is already active. Skipping firewall config.${NC}"
fi

# === Step 2: Setup Directory ===
WORKDIR="/opt/popcache"
echo -e "${CYAN}Creating working directory at $WORKDIR...${NC}"
sudo mkdir -p "$WORKDIR"
sudo chown "$USER":"$USER" "$WORKDIR"
cd "$WORKDIR" || exit 1

# === Step 3: Download and Extract PoP Binary ===
echo -e "${CYAN}Downloading PoP binary v0.3.0...${NC}"
wget -q --show-progress https://download.pipe.network/static/pop-v0.3.0-linux-x64.tar.gz -O pop.tar.gz
echo -e "${CYAN}Extracting PoP binary...${NC}"
tar -xzf pop.tar.gz
chmod +x pop

# === Step 4: Interactive Configuration ===
read -p "Enter a unique PoP node name (pop_name): " POP_NAME
read -p "Enter the PoP location (e.g., Ho Chi Minh, VN): " POP_LOCATION
read -p "Enter your invite code: " INVITE_CODE
read -p "Enter your node name (node_name): " NODE_NAME
read -p "Enter your name (name): " NAME
read -p "Enter your email address: " EMAIL
read -p "Enter your website (or leave blank): " WEBSITE
read -p "Enter your Discord username (or leave blank): " DISCORD
read -p "Enter your Telegram handle (or leave blank): " TELEGRAM
read -p "Enter your Solana wallet address (solana_pubkey): " SOLANA_PUBKEY

# === Step 5: Performance Settings ===
echo -e "${CYAN}Default performance settings:${NC}"
echo -e "  - Workers: 40"
echo -e "  - Memory Cache: 4096 MB"
echo -e "  - Disk Cache: 100 GB"
read -p "Do you want to override these defaults? [y/N]: " OVERRIDE

if [[ "$OVERRIDE" =~ ^[Yy]$ ]]; then
  read -p "Enter number of worker threads [default 40]: " WORKERS
  read -p "Enter memory cache size in MB [default 4096]: " MEM_CACHE_MB
  read -p "Enter disk cache size in GB [default 100]: " DISK_CACHE_GB
  WORKERS=${WORKERS:-40}
  MEM_CACHE_MB=${MEM_CACHE_MB:-4096}
  DISK_CACHE_GB=${DISK_CACHE_GB:-100}
else
  WORKERS=40
  MEM_CACHE_MB=4096
  DISK_CACHE_GB=100
fi

# === Step 6: Generate config.json ===
echo -e "${CYAN}Preview of configuration:${NC}"
CONFIG_JSON=$(cat <<EOF
{
  "pop_name": "$POP_NAME",
  "pop_location": "$POP_LOCATION",
  "invite_code": "$INVITE_CODE",
  "server": {
    "host": "0.0.0.0",
    "port": 443,
    "http_port": 80,
    "workers": $WORKERS
  },
  "cache_config": {
    "memory_cache_size_mb": $MEM_CACHE_MB,
    "disk_cache_path": "./cache",
    "disk_cache_size_gb": $DISK_CACHE_GB,
    "default_ttl_seconds": 86400,
    "respect_origin_headers": true,
    "max_cacheable_size_mb": 1024
  },
  "api_endpoints": {
    "base_url": "https://dataplane.pipenetwork.com"
  },
  "identity_config": {
    "node_name": "$NODE_NAME",
    "name": "$NAME",
    "email": "$EMAIL",
    "website": "$WEBSITE",
    "discord": "$DISCORD",
    "telegram": "$TELEGRAM",
    "solana_pubkey": "$SOLANA_PUBKEY"
  }
}
EOF
)

echo -e "${YELLOW}"
echo "$CONFIG_JSON" | jq .
echo -e "${NC}"

read -p "Is this config correct? [Y/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
  echo -e "${RED}Aborted. Please rerun to reconfigure.${NC}"
  exit 1
fi

echo "$CONFIG_JSON" | sudo tee "$WORKDIR/config.json" > /dev/null
sudo mkdir -p /opt/popcache/logs
# === Step 7: Setup systemd Service ===
SERVICE_FILE="/etc/systemd/system/pop.service"
echo -e "${CYAN}Creating systemd service at $SERVICE_FILE...${NC}"

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=POP Cache Node
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/popcache
ExecStart=/opt/popcache/pop
Restart=always
RestartSec=5
LimitNOFILE=65535
StandardOutput=append:/opt/popcache/logs/stdout.log
StandardError=append:/opt/popcache/logs/stderr.log
Environment=POP_CONFIG_PATH=/opt/popcache/config.json

[Install]
WantedBy=multi-user.target

# === Step 8: Enable and Start Service ===
echo -e "${CYAN}Starting PoP node service...${NC}"
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable pop
sudo systemctl start pop
sleep 2

STATUS=$(systemctl is-active pop)
if [[ "$STATUS" == "active" ]]; then
  echo -e "${CYAN}✅ PoP Node is running!${NC}"
  echo -e "${YELLOW}🔧 To check logs:  sudo journalctl -u pop -f${NC}"
else
  echo -e "${RED}❌ Service failed. Check with: sudo journalctl -u pop${NC}"
fi
