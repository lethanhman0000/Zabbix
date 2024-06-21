#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Update and upgrade the system
sudo apt-get update
sudo apt-get -y upgrade

# Install dependencies
sudo apt-get install -y wget gnupg2 lsb-release

# Download Zabbix repository package
wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+ubuntu20.04_all.deb

# Install the Zabbix repository package
sudo apt-get install -y ./zabbix-release_5.0-1+ubuntu20.04_all.deb

# Update package index
sudo apt-get update

# Install Zabbix server, frontend, and agent
sudo apt-get install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-agent

# Install MariaDB
sudo apt-get install -y mariadb-server

# Start and enable MariaDB service
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Secure MariaDB installation
sudo mysql_secure_installation

# Create Zabbix database and user
mysql -u root -p <<EOF
CREATE DATABASE zabbix character set utf8 collate utf8_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Import initial schema and data for Zabbix server
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -uzabbix -p'your_password' zabbix

# Update Zabbix server configuration file
sudo sed -i 's/# DBPassword=/DBPassword=your_password/' /etc/zabbix/zabbix_server.conf

# Set timezone in PHP configuration for Zabbix
echo "php_value[date.timezone] = Asia/Ho_Chi_Minh" | sudo tee /etc/php/7.4/apache2/conf.d/99-zabbix.ini

# Restart Zabbix server, agent, and Apache to apply changes
sudo systemctl restart zabbix-server zabbix-agent apache2

# Enable Zabbix server, agent, and Apache to start at boot
sudo systemctl enable zabbix-server zabbix-agent apache2

# Open firewall ports for Zabbix
sudo ufw allow 80/tcp
sudo ufw allow 10051/tcp
sudo ufw enable

# Output success message
echo "Zabbix installation and configuration completed successfully."
echo "Access Zabbix web interface at http://your_server_ip/zabbix"
