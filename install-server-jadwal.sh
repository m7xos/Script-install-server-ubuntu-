#!/usr/bin/env bash
set -e

echo "========== DEPLOY JADWAL (BRANCH: stable) =========="

# ==============================
# CHECK ROOT / SUDO
# ==============================
if [ "$EUID" -ne 0 ]; then
    echo "Script dijalankan bukan sebagai root."
    read -p "Gunakan sudo untuk melanjutkan? (y/n): " SUDOCONFIRM
    if [[ "$SUDOCONFIRM" != "y" ]]; then
        echo "Deploy dibatalkan."
        exit 1
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        echo "sudo tidak tersedia."
        exit 1
    fi

    sudo -v || { echo "User tidak memiliki akses sudo."; exit 1; }

    sudo bash "$0"
    exit 0
fi

# ==============================
# DETEKSI USER ASLI
# ==============================
if [ -n "$SUDO_USER" ]; then
    DEPLOY_USER="$SUDO_USER"
else
    DEPLOY_USER="$(whoami)"
fi

echo "Deploy user : $DEPLOY_USER"

# ==============================
# PASTIKAN /var/www ADA
# ==============================
mkdir -p /var/www
chown -R $DEPLOY_USER:www-data /var/www
chmod -R 775 /var/www

cd /var/www

# ==============================
# CLONE REPO (STABLE ONLY)
# ==============================
if [ -d "/var/www/jadwal" ]; then
    echo "Folder jadwal sudah ada."
    read -p "Hapus dan clone ulang? (y/n): " RECLONE
    if [[ "$RECLONE" == "y" ]]; then
        rm -rf /var/www/jadwal
    else
        echo "Deploy dibatalkan."
        exit 0
    fi
fi

echo "Cloning branch stable saja..."
git clone --branch stable --single-branch https://github.com/m7xos/jadwal.git jadwal

# ==============================
# SET OWNERSHIP & PERMISSION
# ==============================
chown -R $DEPLOY_USER:www-data /var/www/jadwal
chmod -R 775 /var/www/jadwal

# Tambahkan user ke group www-data
usermod -aG www-data $DEPLOY_USER || true

# ==============================
# LARAVEL FIX PERMISSION (Optional)
# ==============================
if [ -d "/var/www/jadwal/storage" ]; then
    chmod -R 775 /var/www/jadwal/storage
fi

if [ -d "/var/www/jadwal/bootstrap/cache" ]; then
    chmod -R 775 /var/www/jadwal/bootstrap/cache
fi

echo "======================================="
echo " DEPLOY SUCCESS"
echo "======================================="
echo "Repository : jadwal"
echo "Branch     : stable"
echo "Location   : /var/www/jadwal"
echo "Owner      : $DEPLOY_USER"
echo "Group      : www-data"
echo "======================================="
