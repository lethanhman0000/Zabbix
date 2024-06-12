#!/bin/bash

# Update the system
apt-get update
apt-get -y upgrade

# Set the timezone
timedatectl set-timezone Asia/Ho_Chi_Minh

# Install Apache
apt-get -y install apache2
systemctl start apache2
systemctl enable apache2

# Install PHP and required extensions
apt-get -y install php php-mysql php-bcmath php-mbstring php-gd php-xml php-ldap php-zip php-fpm
systemctl restart apache2

# Install MariaDB
apt-get -y install mariadb-server mariadb-client
systemctl start mariadb
systemctl enable mariadb

# Secure MariaDB installation
mysql_secure_installation

# Create Zabbix database and user
mysql -u root -p -e "CREATE DATABASE zabbix character set utf8 collate utf8_bin;"
mysql -u root -p -e "GRANT ALL PRIVILEGES ON zabbix.* TO zabbix@'localhost' IDENTIFIED BY '123456';"
mysql -u root -p -e "FLUSH PRIVILEGES;"

# Install Zabbix repository
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu24.04_all.deb
dpkg -i zabbix-release_7.0-1+ubuntu24.04_all.deb
apt-get update

# Install Zabbix server, frontend, agent
apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# Import initial schema and data for Zabbix server
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p zabbix

# Configure Zabbix server
sed -i 's/^# DBPassword=/DBPassword=password/' /etc/zabbix/zabbix_server.conf

# Configure PHP for Zabbix frontend
sed -i 's/^;date.timezone =/date.timezone = Asia\/Ho_Chi_Minh/' /etc/php/7.4/apache2/php.ini

# Configure Zabbix User
sed -i 's/^memory_limit = .*/memory_limit = 128M/' /etc/php/7.4/apache2/php.ini
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 8M/' /etc/php/7.4/apache2/php.ini
sed -i 's/^post_max_size = .*/post_max_size = 16M/' /etc/php/7.4/apache2/php.ini
sed -i 's/^max_execution_time = .*/max_execution_time = 300/' /etc/php/7.4/apache2/php.ini
sed -i 's/^max_input_time = .*/max_input_time = 300/' /etc/php/7.4/apache2/php.ini

# Restart services
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

# Open the firewall ports for Zabbix
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 10050/tcp
ufw allow 10051/tcp
ufw reload

echo "Trong may cua ban co tronscipt cua tui dua vao roi do, tim va xoa no di!!:))"

