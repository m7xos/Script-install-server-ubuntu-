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
        echo "sudo tidak tersedia. Install dibatalkan."
        exit 1
    fi

    sudo -v || { echo "User tidak memiliki akses sudo."; exit 1; }

    echo "Re-running script dengan sudo..."
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

echo "Installing base packages..."
apt install -y software-properties-common curl ca-certificates gnupg unzip

echo "Adding PHP 8.4 repository..."
add-apt-repository ppa:ondrej/php -y
apt update

echo "Installing Apache..."
apt install -y apache2
a2enmod rewrite headers
systemctl enable apache2

echo "Installing PHP 8.4..."
apt install -y \
php8.4 php8.4-cli php8.4-common php8.4-mysql php8.4-curl \
php8.4-gd php8.4-mbstring php8.4-xml php8.4-zip \
php8.4-bcmath php8.4-intl php8.4-opcache \
libapache2-mod-php8.4

# FORCE PHP 8.4 CLI
update-alternatives --set php /usr/bin/php8.4

# FORCE Apache use PHP 8.4
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
echo "Installing MariaDB..."
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
echo "Installing NodeJS LTS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

# ==============================
# GIT
# ==============================
apt install -y git

# ==============================
# COMPOSER
# ==============================
echo "Installing Composer..."
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
    ln -sf /usr/share/phpmyadmin /var/www/html/phpmyadmin
fi

# ==============================
# LARAVEL PERMISSION TEMPLATE
# ==============================
read -p "Set permission Laravel di /var/www/html ? (y/n): " LARAPER
if [[ "$LARAPER" == "y" ]]; then
    chown -R www-data:www-data /var/www/html
    find /var/www/html -type f -exec chmod 644 {} \;
    find /var/www/html -type d -exec chmod 755 {} \;
fi

echo "======================================="
echo " INSTALL COMPLETE"
echo "======================================="
echo "Apache  : $(apache2 -v | head -n1)"
echo "PHP CLI : $(php -v | head -n1)"
echo "Apache Module:"
apachectl -M | grep php || true
echo "MariaDB : $(mysql -V)"
echo "NodeJS  : $(node -v)"
echo "Composer: $(composer --version)"
echo ""
echo "phpMyAdmin (jika diinstall): http://SERVER-IP/phpmyadmin"
echo "======================================="
