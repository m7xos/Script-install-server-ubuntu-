#!/usr/bin/env bash
set -e

echo "========== INSTALLER PHP 8.4 + LARAVEL READY =========="

# ==============================
# CHECK ROOT / SUDO
# ==============================
if [ "$EUID" -ne 0 ]; then
    echo "Script dijalankan bukan sebagai root."
    read -p "Gunakan sudo untuk melanjutkan? (y/n): " SUDOCONFIRM
    if [[ "$SUDOCONFIRM" != "y" ]]; then
        echo "Install dibatalkan."
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
# DETECT UBUNTU VERSION
# ==============================
UBUNTU_VERSION=$(lsb_release -rs)
if [[ "$UBUNTU_VERSION" != "22.04" && "$UBUNTU_VERSION" != "24.04" ]]; then
  echo "Script hanya untuk Ubuntu 22.04 & 24.04"
  exit 1
fi

read -p "Lanjutkan instalasi? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && exit 1

apt update && apt upgrade -y
apt install -y software-properties-common curl ca-certificates gnupg unzip

# ==============================
# PHP 8.4 REPO
# ==============================
add-apt-repository ppa:ondrej/php -y
apt update

# ==============================
# APACHE
# ==============================
apt install -y apache2
a2enmod rewrite headers
systemctl enable apache2

# UBAH DOCUMENT ROOT KE /var/www
sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www|g' \
/etc/apache2/sites-available/000-default.conf

# Hapus folder html jika ada
rm -rf /var/www/html
mkdir -p /var/www
chown -R www-data:www-data /var/www

systemctl restart apache2

# ==============================
# PHP 8.4
# ==============================
apt install -y \
php8.4 php8.4-cli php8.4-common php8.4-mysql php8.4-curl \
php8.4-gd php8.4-mbstring php8.4-xml php8.4-zip \
php8.4-bcmath php8.4-intl php8.4-opcache \
libapache2-mod-php8.4

update-alternatives --set php /usr/bin/php8.4
a2dismod php* || true
a2enmod php8.4
systemctl restart apache2

# ==============================
# LARAVEL PRODUCTION TUNING
# ==============================
PHPINI="/etc/php/8.4/apache2/php.ini"

sed -i "s/expose_php = On/expose_php = Off/" $PHPINI
sed -i "s/display_errors = On/display_errors = Off/" $PHPINI
sed -i "s/memory_limit = .*/memory_limit = 512M/" $PHPINI

cat >> $PHPINI <<EOF

; Laravel Production Optimization
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0
EOF

systemctl restart apache2

# ==============================
# MARIADB
# ==============================
apt install -y mariadb-server mariadb-client
systemctl enable mariadb
systemctl start mariadb

read -p "Amankan MariaDB sekarang? (mysql_secure_installation) (y/n): " DBSEC
if [[ "$DBSEC" == "y" ]]; then
    mysql_secure_installation
fi

# ==============================
# NODEJS
# ==============================
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

# ==============================
# GIT
# ==============================
apt install -y git

# ==============================
# COMPOSER
# ==============================
EXPECTED_CHECKSUM="$(php -r "copy('https://composer.github.io/installer.sig', 'php://stdout');")"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
  echo 'Composer installer corrupt'
  rm composer-setup.php
  exit 1
fi

php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

# ==============================
# PHPMYADMIN
# ==============================
read -p "Install phpMyAdmin? (akan muncul dialog konfigurasi) (y/n): " PMA
if [[ "$PMA" == "y" ]]; then
    apt install phpmyadmin
    update-alternatives --set php /usr/bin/php8.4
    a2dismod php* || true
    a2enmod php8.4
    systemctl restart apache2
    ln -sf /usr/share/phpmyadmin /var/www/phpmyadmin
fi

# ==============================
# LARAVEL PERMISSION TEMPLATE
# ==============================
read -p "Set permission Laravel di /var/www ? (y/n): " LARAPER
if [[ "$LARAPER" == "y" ]]; then
    chown -R www-data:www-data /var/www
    find /var/www -type f -exec chmod 644 {} \;
    find /var/www -type d -exec chmod 755 {} \;
fi

echo "======================================="
echo " INSTALL COMPLETE"
echo "======================================="
echo "DocumentRoot : /var/www"
echo "PHP CLI      : $(php -v | head -n1)"
echo "Apache PHP   :"
apachectl -M | grep php || true
echo "======================================="
