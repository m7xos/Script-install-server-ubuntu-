#!/usr/bin/env bash
set -e

echo "========== FULL SERVER INSTALL WA =========="

# =============================
# CHECK ROOT
# =============================
if [ "$EUID" -ne 0 ]; then
  echo "Harus dijalankan sebagai root."
  exit 1
fi

read -p "Lanjutkan instalasi server? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && exit 0

apt update && apt upgrade -y
apt install -y software-properties-common curl gnupg ca-certificates lsb-release unzip git

# =============================
# APACHE
# =============================
echo "Installing Apache..."
apt install -y apache2
a2enmod rewrite proxy proxy_http headers ssl
systemctl enable apache2

# =============================
# PHP 8.4 FPM
# =============================
echo "Installing PHP 8.4 FPM..."
add-apt-repository ppa:ondrej/php -y
apt update

apt install -y php8.4 php8.4-fpm php8.4-cli php8.4-common \
php8.4-mysql php8.4-curl php8.4-gd php8.4-mbstring \
php8.4-xml php8.4-zip php8.4-bcmath php8.4-intl php8.4-opcache

update-alternatives --set php /usr/bin/php8.4
a2enconf php8.4-fpm
systemctl restart apache2

# =============================
# MARIADB
# =============================
echo "Installing MariaDB..."
apt install -y mariadb-server mariadb-client
systemctl enable mariadb
systemctl start mariadb

read -p "Amankan MariaDB sekarang? (mysql_secure_installation) (y/n): " DBSEC
[[ "$DBSEC" == "y" ]] && mysql_secure_installation

# =============================
# NODEJS LTS
# =============================
echo "Installing NodeJS LTS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

# =============================
# COMPOSER
# =============================
echo "Installing Composer..."
php -r "copy('https://getcomposer.org/installer','composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm -f composer-setup.php

# =============================
# PHPMYADMIN
# =============================
read -p "Install phpMyAdmin? (y/n): " PMA
if [[ "$PMA" == "y" ]]; then
  apt install -y phpmyadmin
  update-alternatives --set php /usr/bin/php8.4
  systemctl restart apache2
  ln -sf /usr/share/phpmyadmin /var/www/html/phpmyadmin
fi

# =============================
# OPTIONAL VHOST
# =============================
DOMAIN=""
read -p "Konfigurasi VHOST WA-Gateway? (y/n): " VHOSTCHOICE
if [[ "$VHOSTCHOICE" == "y" ]]; then
  read -p "Masukkan domain (contoh: wa.domain.com): " DOMAIN

  cat > /etc/apache2/sites-available/wa-gateway.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN

    ErrorLog \${APACHE_LOG_DIR}/wa-gateway-error.log
    CustomLog \${APACHE_LOG_DIR}/wa-gateway-access.log combined
</VirtualHost>
EOF

  a2ensite wa-gateway.conf
  systemctl reload apache2

  echo "VHOST aktif di http://$DOMAIN"
fi

# =============================
# OPTIONAL REVERSE PROXY (/gateway/)
# =============================
read -p "Setup Reverse Proxy → localhost:5001 di /gateway/? (y/n): " PROXYCHOICE
if [[ "$PROXYCHOICE" == "y" ]]; then

  if [[ -z "$DOMAIN" ]]; then
    read -p "Masukkan domain untuk reverse proxy: " DOMAIN
  fi

  cat > /etc/apache2/sites-available/wa-gateway-proxy.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN

    ProxyPreserveHost On
    ProxyPass /gateway/ http://127.0.0.1:5001/
    ProxyPassReverse /gateway/ http://127.0.0.1:5001/

    ErrorLog \${APACHE_LOG_DIR}/wa-gateway-proxy-error.log
    CustomLog \${APACHE_LOG_DIR}/wa-gateway-proxy-access.log combined
</VirtualHost>
EOF

  a2ensite wa-gateway-proxy.conf
  systemctl reload apache2

  echo "Reverse Proxy aktif:"
  echo "http://$DOMAIN/gateway/ → localhost:5001"
fi

# =============================
# OPTIONAL SSL
# =============================
read -p "Generate SSL self-signed? (y/n): " SSLCHOICE
if [[ "$SSLCHOICE" == "y" ]]; then

  if [[ -z "$DOMAIN" ]]; then
    read -p "Masukkan domain untuk SSL: " DOMAIN
  fi

  mkdir -p /etc/apache2/ssl
  openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/apache2/ssl/server.key \
  -out /etc/apache2/ssl/server.crt \
  -subj "/C=ID/ST=Indonesia/L=Wonosobo/O=WA/CN=$DOMAIN"

  cat > /etc/apache2/sites-available/wa-ssl.conf <<EOF
<VirtualHost *:443>
    ServerName $DOMAIN
    SSLEngine on
    SSLCertificateFile /etc/apache2/ssl/server.crt
    SSLCertificateKeyFile /etc/apache2/ssl/server.key

    ProxyPreserveHost On
    ProxyPass /gateway/ http://127.0.0.1:5001/
    ProxyPassReverse /gateway/ http://127.0.0.1:5001/
</VirtualHost>
EOF

  a2ensite wa-ssl.conf
  systemctl reload apache2

  echo "SSL aktif di https://$DOMAIN/gateway/"
fi

echo "=================================="
echo " SERVER INSTALL COMPLETE"
echo "=================================="
echo "Apache  : $(apache2 -v | head -n1)"
echo "PHP     : $(php -v | head -n1)"
echo "MariaDB : $(mysql -V)"
echo "NodeJS  : $(node -v)"
echo "Composer: $(composer --version)"
echo "=================================="
