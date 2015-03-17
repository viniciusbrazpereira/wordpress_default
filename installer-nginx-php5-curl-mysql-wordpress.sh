#!/bin/bash
#This script installs mysql (latest build)
#Install MYSQL Server
mysql_pass=1234
export DEBIAN_FRONTEND=noninteractive 
debconf-set-selections <<< 'mysql-server-5.5 mysql-server/root_password password '$mysql_pass''
debconf-set-selections <<< 'mysql-server-5.5 mysql-server/root_password_again password '$mysql_pass''
sudo apt-get update
sudo apt-get install mysql-server-5.5 -y
#Configure Password and Settings for Remote Access
cp /etc/mysql/my.cnf /etc/mysql/my.bak.cnf
ip=`ifconfig eth0 | grep "inet addr"| cut -d ":" -f2 | cut -d " " -f1` ; sed -i "s/\(bind-address[\t ]*\)=.*/\1= $ip/" /etc/mysql/my.cnf
mysql -uroot -p$mysql_pass -e "UPDATE mysql.user SET Password=PASSWORD('"$mysql_pass"') WHERE User='root'; FLUSH PRIVILEGES;"
sleep 10
mysql -uroot -p$mysql_pass -e "CREATE DATABASE wordpress; GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '"$mysql_pass"'; FLUSH PRIVILEGES;"
#Restart service mysql
sudo service mysql restart
echo "MySQL Installation and Configuration is Complete."
#Install PHP
sudo apt-get install php5-gd libssh2-php php5-mysql -y &&
sudo apt-get install curl libcurl3 libcurl3-dev php5-curl -y &&
sudo apt-get install nginx -y &&
#Install Wordpress
sudo wget http://wordpress.org/latest.tar.gz
sudo tar xzvf latest.tar.gz
cd /home/vagrant/wordpress

#Install Varnish
sudo curl http://repo.varnish-cache.org/debian/GPG-key.txt | sudo apt-key add - &&
sudo sh -c 'echo "deb http://repo.varnish-cache.org/ubuntu/ lucid varnish-3.0" >> /etc/apt/sources.list'
sudo apt-get update
sudo apt-get install varnish -y

#write vhosts varnish backend (ie. nginx) listening in on port 8080.
VHOST_VARNISH="/etc/varnish/default.vcl"
sudo rm -rf ${VHOST_VARNISH};

sudo cat << 'EOF' > ${VHOST_VARNISH}
# This is a basic VCL configuration file for varnish.  See the vcl(7)
# man page for details on VCL syntax and semantics.
#
# Default backend definition.  Set this to point to your content
# server.
#
backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

# Drop any cookies sent to Wordpress.
sub vcl_recv {
        if (!(req.url ~ "wp-(login|admin)")) {
                unset req.http.cookie;
        }
}

# Drop any cookies Wordpress tries to send back to the client.
sub vcl_fetch {
        if (!(req.url ~ "wp-(login|admin)")) {
                unset beresp.http.set-cookie;
        }
}
EOF

#sudo cp wp-config-sample.php wp-config.php
sudo mkdir -p /var/www/html
sudo rsync -avP /home/vagrant/wordpress/ /var/www/html/
cd /var/www/html
sudo mkdir /var/www/html/wp-content/uploads
sudo chown -R www-data:www-data *
sudo apt-get install htop nmap -y
#Install PHP e clone files (default, wp-config.php and varnish) 
sudo apt-get install git -y
cd /home/vagrant
git clone https://github.com/viniciusbrazpereira/config.git
#Copy files (default, wp-config.php)
sudo cp /home/vagrant/config/default /etc/nginx/sites-enabled/default
sudo cp /home/vagrant/config/wp-config.php /var/www/html
sudo cp /home/vagrant/config/varnish /etc/default/varnish
#Restart service VARNISH, PHP e NGINX
sudo service php5-fpm restart
sudo service nginx restart
sudo service varnish restart

echo "Configuration is Complete."


