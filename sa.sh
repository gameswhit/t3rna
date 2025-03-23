#!/bin/bash

# Menampilkan ASCII Art untuk "Saandy"
echo "
  ██████ ▄▄▄     ▄▄▄      ███▄    █▓█████▓██   ██▓
▒██    ▒▒████▄  ▒████▄    ██ ▀█   █▒██▀ ██▒██  ██▒
░ ▓██▄  ▒██  ▀█▄▒██  ▀█▄ ▓██  ▀█ ██░██   █▌▒██ ██░
  ▒   ██░██▄▄▄▄█░██▄▄▄▄██▓██▒  ▐▌██░▓█▄   ▌░ ▐██▓░
▒██████▒▒▓█   ▓██▓█   ▓██▒██░   ▓██░▒████▓ ░ ██▒▓░
▒ ▒▓▒ ▒ ░▒▒   ▓▒█▒▒   ▓▒█░ ▒░   ▒ ▒ ▒▒▓  ▒  ██▒▒▒ 
░ ░▒  ░ ░ ▒   ▒▒ ░▒   ▒▒ ░ ░░   ░ ▒░░ ▒  ▒▓██ ░▒░ 
░  ░  ░   ░   ▒   ░   ▒     ░   ░ ░ ░ ░  ░▒ ▒ ░░  
      ░       ░  ░    ░  ░        ░   ░   ░ ░     
                                    ░     ░ ░     
"

# Set Executor User
EXECUTOR_USER="root"


# Menghentikan dan menghapus service lama jika ada
if systemctl list-units --full -all | grep -q "t3rn-executor.service"; then
    sudo systemctl stop t3rn-executor.service
    sudo systemctl disable t3rn-executor.service
    sudo systemctl daemon-reload
fi

# Menghapus file lama
sudo rm -rf /home/$EXECUTOR_USER/t3rn
sudo rm -rf /etc/systemd/system/t3rn-executor.service
sudo rm -rf /etc/t3rn-executor.env

# Set Private Key
PRIVATE_KEY_LOCAL="0xd6148a6a780a73677aa06cf0a90302d19ced83fd3c829b64e3081973058aa839"

# Set Alchemy API Key
APIKEY_ALCHEMY="75YKBFImV33CB3a-WKTJ1pKbV57UTf-y"

# Set Gas Price
GAS_PRICE="2000"


INSTALL_DIR="/home/$EXECUTOR_USER/t3rn"
SERVICE_FILE="/etc/systemd/system/t3rn-executor.service"
ENV_FILE="/etc/t3rn-executor.env"
EXECUTOR_VERSION="v0.53.1"
EXECUTOR_FILE="executor-linux-$EXECUTOR_VERSION.tar.gz"
EXECUTOR_URL="https://github.com/t3rn/executor-release/releases/download/$EXECUTOR_VERSION/$EXECUTOR_FILE"

# Pastikan direktori ada
mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

# Cek koneksi sebelum mengunduh
if curl --output /dev/null --silent --head --fail "$EXECUTOR_URL"; then
    echo "🔽 Mengunduh Executor dari $EXECUTOR_URL..."
    curl -L -o "$EXECUTOR_FILE" "$EXECUTOR_URL"
else
    echo "❌ URL tidak dapat diakses, pastikan koneksi internet stabil."
    exit 1
fi

# Ekstrak file
echo "📦 Mengekstrak Executor..."
tar -xzvf "$EXECUTOR_FILE" || {
    echo "❌ Gagal mengekstrak file. Pastikan format file benar."
    exit 1
}

# Bersihkan file unduhan
rm -f "$EXECUTOR_FILE"

# Pastikan direktori yang diperlukan ada sebelum masuk
if [ -d "executor/executor/bin" ]; then
    cd executor/executor/bin || exit 1
    echo "✅ Executor berhasil diunduh dan diekstrak."
else
    echo "❌ Direktori 'executor/executor/bin' tidak ditemukan! Ekstraksi mungkin gagal."
    exit 1
fi

# Konfigurasi environment file
sudo bash -c "cat > $ENV_FILE" <<EOL
RPC_ENDPOINTS='{
  "l2rn": ["http://b2n.rpc.caldera.xyz/http"],
  "arbt": ["https://arbitrum-sepolia.drpc.org", "https://arb-sepolia.g.alchemy.com/v2/$APIKEY_ALCHEMY"],
  "bast": ["https://base-sepolia-rpc.publicnode.com", "https://base-sepolia.g.alchemy.com/v2/$APIKEY_ALCHEMY"],
  "opst": ["https://sepolia.optimism.io", "https://opt-sepolia.g.alchemy.com/v2/$APIKEY_ALCHEMY"],
  "unit": ["https://unichain-sepolia.drpc.org", "https://unichain-sepolia.g.alchemy.com/v2/$APIKEY_ALCHEMY"]
}'
EXECUTOR_MAX_L3_GAS_PRICE="$GAS_PRICE"
PRIVATE_KEY_LOCAL="$PRIVATE_KEY_LOCAL"
ENABLED_NETWORKS="l2rn,arbitrum-sepolia,base-sepolia,optimism-sepolia,unichain-sepolia"
EOL

# Berikan hak akses ke user
sudo chown -R "$EXECUTOR_USER":"$EXECUTOR_USER" "$INSTALL_DIR"
sudo chmod 600 "$ENV_FILE"

# Buat systemd service
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=t3rn Executor Service
After=network.target

[Service]
User=$EXECUTOR_USER
WorkingDirectory=$INSTALL_DIR/executor/executor/bin
ExecStart=$INSTALL_DIR/executor/executor/bin/executor
Restart=always
RestartSec=10
Environment=ENVIRONMENT=testnet
Environment=LOG_LEVEL=debug
Environment=LOG_PRETTY=false
Environment=EXECUTOR_PROCESS_BIDS_ENABLED=true
Environment=EXECUTOR_PROCESS_ORDERS_ENABLED=true
Environment=EXECUTOR_PROCESS_CLAIMS_ENABLED=true
Environment=EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=false
Environment=EXECUTOR_PROCESS_ORDERS_API_ENABLED=false
EnvironmentFile=$ENV_FILE
Environment=ENABLED_NETWORKS=l2rn,arbitrum-sepolia,base-sepolia,blst-sepolia,optimism-sepolia,unichain-sepolia

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd dan jalankan service
sudo systemctl daemon-reload
sudo systemctl enable t3rn-executor.service
sudo systemctl start t3rn-executor.service

# Tampilkan status layanan dan log secara real-time
echo "✅ Executor berhasil diinstall. Menampilkan status dan log..."
sudo systemctl status t3rn-executor.service --no-pager
sudo journalctl -u t3rn-executor.service -f --no-hostname -o cat
