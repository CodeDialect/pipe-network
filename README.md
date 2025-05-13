
# Pipe Network Testnet Node Setup

This guide helps you install and run a PoP (Proof of Processing) node for the [Pipe Network Testnet](https://docs.pipe.network/nodes/testnet) on a Linux-based system (Ubuntu recommended).

---

## Prerequisites

- A Linux server (Ubuntu 20.04+)
- Root or sudo access
- Open ports: `443`, `8080`, `22` (for SSH)
- GCP: Ensure firewall rules allow TCP 443 and 8080

---

## Installation Steps

### 1. Update and Install Dependencies

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl unzip ufw jq git -y
```

### 2. Clone or Download This Repo

```bash
git clone https://github.com/CodeDialect/pipe-network.git
cd pipe-network
```
### 3. Check your region
```bash
curl ipinfo.io
```

### 4. Run the Setup Script

```bash
chmod +x setup.sh
./setup.sh
```

This script will:
- Install dependencies (curl, unzip, ufw, jq)
- Set up firewall rules
- Download and extract the `pop` binary
- Prompt for configuration values
- Create and start a `systemd` service for the node

---

## Configuration Options

During setup, you'll be prompted to provide:

### Identity Keys
- `identity_private_key`
- `identity_public_key`

These can be obtained from the Pipe Network CLI.

### Cache Settings
- `memory_cache_size_mb`
- `disk_cache_size_gb`
- `workers` (number of CPU threads to use)

You can re-edit the config later at:
```bash
/opt/popcache/config.json
```

---

## Monitor
```bash
tail -f /opt/popcache/logs/stdout.log
tail -f /opt/popcache/logs/stderr.log
```

### Start/Stop the Node
```bash
sudo systemctl start pop
sudo systemctl stop pop
sudo systemctl restart pop
```

### Check Status
```bash
systemctl status pop
```

### Live Logs
```bash
sudo journalctl -u pop -f
```

---

## Firewall Configuration

The script opens:
- `443/tcp`  PoP API port
- `8080/tcp`  Optional monitoring or HTTP port

Verify with:

```bash
sudo ufw status
```

---

## Troubleshooting

### Error: `0.0.0.0:443 permission denied`
Grant permission using:

```bash
sudo setcap 'cap_net_bind_service=+ep' /opt/popcache/pop
sudo kill -9 $(sudo lsof -t -i :80)
sudo systemctl restart pop
```

---

## Uninstall

To remove the node:

```bash
sudo systemctl stop pop
sudo systemctl disable pop
sudo rm /etc/systemd/system/pop.service
sudo systemctl daemon-reload
sudo rm -rf /opt/popcache
```

---

## Resources

- [Pipe Network Docs](https://docs.pipe.network/nodes/testnet)

---

## License

MIT License
