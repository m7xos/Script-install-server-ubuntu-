#!/usr/bin/env bash
set -e

echo "========== DEPLOY JADWAL (STABLE) =========="

# ==============================
# CHECK ROOT / SUDO
# ==============================
if [ "$EUID" -ne 0 ]; then
    read -p "Gunakan sudo? (y/n): " SUDOCONFIRM
    [[ "$SUDOCONFIRM" != "y" ]] && exit 1
    sudo -v || exit 1
    sudo bash "$0"
    exit 0
fi

# ==============================
# OPTIONAL USER CREATION
# ==============================
read -p "Buat user baru? (y/n): " CREATEUSER

if [[ "$CREATEUSER" == "y" ]]; then
    read -p "Username: " NEWUSER

    if ! id "$NEWUSER" >/dev/null 2>&1; then
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
    fi
fi

# ==============================
# DETEKSI USER DEPLOY
# ==============================
if [ -n "$SUDO_USER" ]; then
    DEPLOY_USER="$SUDO_USER"
else
    DEPLOY_USER="$(whoami)"
fi

mkdir -p /var/www
chown -R $DEPLOY_USER:www-data /var/www
chmod -R 775 /var/www

cd /var/www

if [ -d "jadwal" ]; then
    read -p "Folder jadwal sudah ada. Hapus? (y/n): " RECLONE
    [[ "$RECLONE" == "y" ]] && rm -rf jadwal || exit 0
fi

git clone --branch stable --single-branch \
https://github.com/m7xos/jadwal.git jadwal

chown -R $DEPLOY_USER:www-data /var/www/jadwal
chmod -R 775 /var/www/jadwal

if [ -d "jadwal/storage" ]; then
    chmod -R 775 jadwal/storage
fi

if [ -d "jadwal/bootstrap/cache" ]; then
    chmod -R 775 jadwal/bootstrap/cache
fi

usermod -aG www-data $DEPLOY_USER || true

echo "===== DEPLOY SUCCESS ====="
echo "Location: /var/www/jadwal"
echo "Owner   : $DEPLOY_USER"
