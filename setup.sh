#!/bin/bash

# Update and upgrade the system
sudo apt-get update
sudo apt-get -y upgrade

# Download Zabbix repository package
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu24.04_all.deb

apt-get install ./zabbix-release_7.0-1+ubuntu24.04_all.deb

# Update package index
apt-get update

# Install Zabbix server, frontend, and agent
apt-get install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-agent -y

# Install MariaDB
apt-get install mariadb-server -y

# Start and enable MariaDB service
systemctl start mariadb
systemctl enable mariadb

# Secure MariaDB installation
MYSQL_ROOT_PASSWORD="123456"
mysql --user=root --password="$MYSQL_ROOT_PASSWORD" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Create Zabbix database and user
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE zabbix character set utf8 collate utf8_bin;"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'your_password';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
# Import initial schema and data for Zabbix server
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -uzabbix -p'123456' zabbix

# Update Zabbix server configuration file
sed -i 's/# DBPassword=/DBPassword=123456/' /etc/zabbix/zabbix_server.conf

# Set timezone in PHP configuration for Zabbix
sed -i 's/;date.timezone =.*/date.timezone = Asia\/Ho_Chi_Minh/' /etc/php/8.3/apache2/conf.d/99-zabbix.ini

# Restart Zabbix server, agent, and Apache to apply changes
systemctl restart zabbix-server zabbix-agent apache2

# Enable Zabbix server, agent, and Apache to start at boot
systemctl enable zabbix-server zabbix-agent apache2

# Open firewall ports for Zabbix
ufw allow 80/tcp
ufw allow 10051/tcp
ufw enable
