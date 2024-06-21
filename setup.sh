#!/bin/bash

# Update the system
apt-get update
apt-get -y upgrade

# Set the timezone
timedatectl set-timezone Asia/Ho_Chi_Minh

# Install PHP and required extensions
apt-get install mariadb-server mariadb-client apache2 php php-mysql php-bcmath php-intl php-mbstring php-gd php-xml php-ldap php-zip php-fpm -y

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

tee /etc/mysql/mariadb.conf.d/50-server.cnf > /dev/null <<EOL
[server]

# this is only for the mysqld standalone daemon
[mysqld]
max_heap_table_size = 128M
tmp_table_size = 64M
join_buffer_size = 256K
innodb_file_format = Barracuda
innodb_large_prefix = 1
innodb_buffer_pool_size = 1024M
innodb_flush_log_at_timeout = 3
innodb_read_io_threads = 32
innodb_write_io_threads = 16
innodb_io_capacity = 5000
innodb_io_capacity_max = 10000
sort_buffer_size = 100K
innodb_doublewrite = OFF
#
# * Basic Settings
#

#user                    = mysql
pid-file                = /run/mysqld/mysqld.pid
basedir                 = /usr
#datadir                 = /var/lib/mysql
#tmpdir                  = /tmp

# Broken reverse DNS slows down connections considerably and name resolve is
# safe to skip if there are no "host by domain name" access grants
#skip-name-resolve

# Instead of skip-networking the default is now to listen only on
# localhost which is more compatible and is not less secure.
bind-address            = 127.0.0.1

#
# * Fine Tuning
#

#key_buffer_size        = 128M
#max_allowed_packet     = 1G
#thread_stack           = 192K
#thread_cache_size      = 8
# This replaces the startup script and checks MyISAM tables if needed
# the first time they are touched
#myisam_recover_options = BACKUP
#max_connections        = 100
#table_cache            = 64

#
# * Logging and Replication
#

# Note: The configured log file or its directory need to be created
# and be writable by the mysql user, e.g.:
# $ sudo mkdir -m 2750 /var/log/mysql
# $ sudo chown mysql /var/log/mysql

# Both location gets rotated by the cronjob.
# Be aware that this log type is a performance killer.
# Recommend only changing this at runtime for short testing periods if needed!
#general_log_file       = /var/log/mysql/mysql.log
#general_log            = 1

# When running under systemd, error logging goes via stdout/stderr to journald
# and when running legacy init error logging goes to syslog due to
# /etc/mysql/conf.d/mariadb.conf.d/50-mysqld_safe.cnf
# Enable this if you want to have error logging into a separate file
#log_error = /var/log/mysql/error.log
# Enable the slow query log to see queries with especially long duration
#log_slow_query_file    = /var/log/mysql/mariadb-slow.log
#log_slow_query_time    = 10
#log_slow_verbosity     = query_plan,explain
#log-queries-not-using-indexes
#log_slow_min_examined_row_limit = 1000

# The following can be used as easy to replay backup logs or for replication.
# note: if you are setting up a replica, see README.Debian about other
#       settings you may need to change.
#server-id              = 1
#log_bin                = /var/log/mysql/mysql-bin.log
expire_logs_days        = 10
#max_binlog_size        = 100M

#
# * SSL/TLS
#

# For documentation, please read
# https://mariadb.com/kb/en/securing-connections-for-client-and-server/
#ssl-ca = /etc/mysql/cacert.pem
#ssl-cert = /etc/mysql/server-cert.pem
#ssl-key = /etc/mysql/server-key.pem
#require-secure-transport = on

#
# * Character sets
#

# MySQL/MariaDB default is Latin1, but in Debian we rather default to the full
# utf8 4-byte character set. See also client.cnf
character-set-server  = utf8mb4
collation-server      = utf8mb4_unicode_ci

#
# * InnoDB
#

# InnoDB is enabled by default with a 10MB datafile in /var/lib/mysql/.
# Read the manual for more InnoDB related options. There are many!
# Most important is to give InnoDB 80 % of the system RAM for buffer use:
# https://mariadb.com/kb/en/innodb-system-variables/#innodb_buffer_pool_size
#innodb_buffer_pool_size = 8G

# this is only for embedded server
[embedded]

# This group is only read by MariaDB servers, not by MySQL.
# If you use the same .cnf file for MySQL and MariaDB,
# you can put MariaDB-only options here
[mariadb]

# Doi Version tuy theo phien ban mariadb, cai nay la version 2024
[mariadb-10.11.7]
EOL

systemctl restart mariadb
systemctl restart apache2
systemctl start apache2
systemctl enable apache2
systemctl start mariadb
systemctl enable mariadb
# Install Zabbix repository
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu24.04_all.deb
dpkg -i zabbix-release_7.0-1+ubuntu24.04_all.deb
apt update

# Install Zabbix server, frontend, agent
apt-get install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent mysql-servver -y
systemctl start mysql

# Create Zabbix database and user
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "create user 'zabbix'@'localhost' identified by '123456';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "grant all privileges on zabbix.* to 'zabbix'@'localhost';"

# Import initial schema and data for Zabbix server
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p'123456' zabbix

# Configure Zabbix server
sed -i 's/^# DBPassword=/DBPassword=123456/' /etc/zabbix/zabbix_server.conf

# Configure PHP for Zabbix frontend
sed -i 's/^;date.timezone =/date.timezone = Asia\/Ho_Chi_Minh/' /etc/php/8.3/apache2/php.ini

# Configure Zabbix User
sed -i 's/^memory_limit = .*/memory_limit = 128M/' /etc/php/8.3/apache2/php.ini
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 8M/' /etc/php/8.3/apache2/php.ini
sed -i 's/^post_max_size = .*/post_max_size = 16M/' /etc/php/8.3/apache2/php.ini
sed -i 's/^max_execution_time = .*/max_execution_time = 300/' /etc/php/8.3/apache2/php.ini
sed -i 's/^max_input_time = .*/max_input_time = 300/' /etc/php/8.3/apache2/php.ini

# Restart services
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

# Open the firewall ports for Zabbix
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 10050/tcp
ufw allow 10051/tcp
ufw reload
