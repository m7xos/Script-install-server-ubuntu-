#!/usr/bin/env bash
set -e

echo "========== DEPLOY WA-GATEWAY =========="

# =================================
# CHECK ROOT / SUDO
# =================================
if [ "$EUID" -ne 0 ]; then
    echo "Script bukan dijalankan sebagai root."
    read -p "Gunakan sudo? (y/n): " SUDOCONFIRM
    [[ "$SUDOCONFIRM" != "y" ]] && exit 1
    sudo -v || { echo "Tidak memiliki akses sudo."; exit 1; }
    sudo bash "$0"
    exit 0
fi

# =================================
# OPTIONAL USER CREATION
# =================================
read -p "Buat user baru untuk deploy? (y/n): " CREATEUSER

if [[ "$CREATEUSER" == "y" ]]; then
    read -p "Masukkan username baru: " NEWUSER

    if id "$NEWUSER" >/dev/null 2>&1; then
        echo "User sudah ada."
    else
        while true; do
            read -s -p "Password: " PASS1; echo
            read -s -p "Konfirmasi Password: " PASS2; echo
            [[ "$PASS1" == "$PASS2" ]] && break
            echo "Password tidak sama."
        done

        useradd -m -s /bin/bash "$NEWUSER"
        echo "$NEWUSER:$PASS1" | chpasswd
        usermod -aG sudo "$NEWUSER"
        usermod -aG www-data "$NEWUSER"

        echo "User $NEWUSER berhasil dibuat dan memiliki akses sudo."
    fi
fi

# =================================
# DETEKSI USER DEPLOY
# =================================
if [ -n "$SUDO_USER" ]; then
    DEPLOY_USER="$SUDO_USER"
else
    DEPLOY_USER="$(whoami)"
fi

echo "Deploy user: $DEPLOY_USER"

# =================================
# PASTIKAN NODEJS TERINSTALL
# =================================
if ! command -v node >/dev/null 2>&1; then
    echo "NodeJS belum terinstall. Installing NodeJS LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt install -y nodejs
fi

# =================================
# INSTALL PM2 GLOBAL
# =================================
if ! command -v pm2 >/dev/null 2>&1; then
    npm install -g pm2
fi

# =================================
# PREPARE DIRECTORY
# =================================
mkdir -p /var/www
chown -R $DEPLOY_USER:www-data /var/www
chmod -R 775 /var/www

cd /var/www

# =================================
# CLONE WA-GATEWAY
# =================================
if [ -d "wa-gateway" ]; then
    read -p "Folder wa-gateway sudah ada. Hapus & clone ulang? (y/n): " RECLONE
    if [[ "$RECLONE" == "y" ]]; then
        rm -rf wa-gateway
    else
        echo "Deploy dibatalkan."
        exit 0
    fi
fi

git clone https://github.com/hardiagunadi/wa-gateway.git wa-gateway

chown -R $DEPLOY_USER:www-data wa-gateway
chmod -R 775 wa-gateway

# =================================
# NPM INSTALL
# =================================
echo "Running npm install..."
sudo -u $DEPLOY_USER bash -c "cd /var/www/wa-gateway && npm install"

# =================================
# START WITH PM2
# =================================
read -p "Start WA-Gateway dengan PM2 sekarang? (y/n): " STARTPM2
if [[ "$STARTPM2" == "y" ]]; then

    sudo -u $DEPLOY_USER bash -c "
        cd /var/www/wa-gateway
        pm2 start index.js --name wa-gateway
        pm2 save
    "

    pm2 startup systemd -u $DEPLOY_USER --hp /home/$DEPLOY_USER
fi

# =================================
# ADD USER TO www-data GROUP
# =================================
usermod -aG www-data $DEPLOY_USER || true

echo "======================================="
echo " WA-GATEWAY DEPLOY SUCCESS"
echo "======================================="
echo "Location : /var/www/wa-gateway"
echo "Owner    : $DEPLOY_USER"
echo "Group    : www-data"
echo "NodeJS   : $(node -v)"
echo "PM2      : $(pm2 -v)"
echo "======================================="
