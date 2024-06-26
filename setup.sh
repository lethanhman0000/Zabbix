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
apt-get install zabbix-sql-scripts zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-agent mariadb-server mariadb-client apache2 php php-mysql php-bcmath php-intl php-mbstring php-gd php-xml php-ldap php-zip php-fpm -y

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
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '123456';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
# Import initial schema and data for Zabbix server
zcat /usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p"123456" zabbix

# Update Zabbix server configuration file
sed -i 's/# DBPassword=/DBPassword=123456/' /etc/zabbix/zabbix_server.conf

# Restart Zabbix server, agent, and Apache to apply changes
systemctl restart zabbix-server zabbix-agent apache2

# Enable Zabbix server, agent, and Apache to start at boot
systemctl enable zabbix-server zabbix-agent apache2

# Open firewall ports for Zabbix
ufw allow 80/tcp
ufw allow 10051/tcp
ufw enable
