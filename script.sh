#!/bin/bash
##################################################
# Created by Yuri Olive <yuriso1994@gmail.com>   #
# Usage:                                         #
#   $ ./script.sh -d <domain>                    #
##################################################

set -e # Exit on first error

function usage() {
    echo "
    Usage:
    $THIS -d <domain>
    $THIS -h (shows this help)
    "
    exit -1
}

while getopts "hd:" OPT; do
  case "$OPT" in
    "h") usage;;
    "d") DOMAIN=$OPTARG ;;
    "?") exit -1;;
  esac
done

if ! "$DOMAIN" || [ -z "$DOMAIN" ] || ! [[ $DOMAIN =~ [-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|] ]]
then
    echo "Error: -e must be completed with your correct domain"
    exit 1  
fi

# Install nginx
sudo apt install nginx -y

# Start nginx
systemctl start nginx
systemctl enable nginx

# Add PHP 7.1 repository
sudo apt install software-properties-common -y
add-apt-repository ppa:ondrej/php -y

# Install PHP 7.1
apt install -y php7.1-fpm php7.1-mcrypt php7.1-curl php7.1-cli php7.1-mysql php7.1-gd php7.1-xsl php7.1-json php7.1-intl php-pear php7.1-dev php7.1-common php7.1-mbstring php7.1-zip php7.1-soap php7.1-bcmath

# Download magento
wget https://github.com/magento/magento2/archive/2.2.6.tar.gz

# Uncompress
tar xvf 2.2.6.tar.gz  

# Move to http server folder
mv magento2-2.2.6/ /var/www/html/magento

# Permission to www-data
chown -R www-data:www-data /var/www/html/ && chmod -R 755 /var/www/html/

# Install composer
apt install composer -y

# Install magento components
cd /var/www/html/magento/ && composer install -v

# Install lets encrypt
apt install letsencrypt -y
systemctl stop nginx
certbot certonly --standalone -d $DOMAIN

# Config nginx
NGINX_CONFIG="upstream fastcgi_backend {\n server unix:/run/php/php7.1-fpm.sock;\n }\n \n server {\n listen 80;\n listen [::]:80;\n server_name "$DOMAIN";\n return 301 https://$server_name$request_uri;\n }\n \n server {\n \n listen 443 ssl;\n server_name "$DOMAIN";\n \n ssl on;\n ssl_certificate /etc/letsencrypt/live/"$DOMAIN"/fullchain.pem;\n ssl_certificate_key /etc/letsencrypt/live/"$DOMAIN"/privkey.pem;\n \n set $MAGE_ROOT /var/www/magento;\n set $MAGE_MODE developer;\n include /var/www/magento/nginx.conf.sample;\n }"
echo -e  > /etc/nginx/sites-available/magento

ln -s /etc/nginx/sites-available/magento /etc/nginx/sites-enabled/

# Restart nginx
systemctl restart php7.1-fpm
systemctl restart nginx