#!/bin/bash

### This script is not fully automated at this time ###

# Pull Private IP Address
IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

# Create Directories
mkdir -p /opt/eshop
mkdir -p /opt/eshop/backend
mkdir -p /opt/eshop/frontend

# Update Hosts File
sed -i.bkp -e '$a'${IP}'   db-host app-host' /etc/hosts

# Disable SELinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Update System
yum -y update

# Install Wget
yum -y install wget

# Install PostgreSQL and Configure
yum -y install postgresql-server
systemctl enable postgresql
postgresql-setup initdb
sed -i.bkp "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf
sed -i.bkp -e '$ahost    all             all              0.0.0.0/0               md5' /var/lib/pgsql/data/pg_hba.conf
systemctl start postgresql

# Change Postresql Password
su - postgres
psql -c "ALTER USER postgres PASSWORD 'root';"
exit

# Install Git and Clone Repo
mkdir /application
yum -y install git
git clone "https://github.com/bezikan/SpringBoot-Angular7-ShoppingCart.git" "/application/SpringBoot-Angular7-ShoppingCart"

# Install Java and Configure
yum -y install java-11-openjdk-devel
alternatives --config java
alternatives --config javac
sed -i.bkp 's/localhost\/postgres/db-host\/postgres/g' /application/SpringBoot-Angular7-ShoppingCart/backend/src/main/resources/application.yml
sed -i.bkp 's/proxy_pass http:\/\/backend:8080\/api/proxy_pass http:\/\/app-host:8080\/api/g' /application/SpringBoot-Angular7-ShoppingCart/frontend/nginx/default.conf
sed -i 's/root \/usr\/share\/nginx\/html/root \/opt\/eshop\/frontend/g' /application/SpringBoot-Angular7-ShoppingCart/frontend/nginx/default.conf

# Setup Maven and Configure
yum -y install maven
cd /application/SpringBoot-Angular7-ShoppingCart/backend/
mvn package -DskipTests
cp target/shop-api-0.0.1-SNAPSHOT.jar /opt/eshop/backend/

# Create Systemd File
bash -c 'cat <<EOF > /usr/lib/systemd/system/eshop.service
[Unit]
Description=EShop Service
[Service]
Type=simple
WorkingDirectory=/opt/eshop/backend
ExecStart=/usr/bin/java -jar /opt/eshop/backend/shop-api-0.0.1-SNAPSHOT.jar
[Install]
WantedBy=multi-user.target
EOF'

# Create Softlink and Start EShop Service
ln -s /usr/lib/systemd/system/eshop.service /etc/systemd/system/multi-user.target.wants/eshop.service
systemctl start eshop

# Setup Frontend Server
yum -y install -y gcc-c++ make
curl -sL https://rpm.nodesource.com/setup_12.x | sudo -E bash -
yum -y install -y nodejs
npm install -g @angular/cli
yum -y install epel-release
yum -y install nginx

# Configure Frontend
cd /application/SpringBoot-Angular7-ShoppingCart/frontend
npm install
ng build --prod
cp -R /application/SpringBoot-Angular7-ShoppingCart/frontend/dist/shop/* /opt/eshop/frontend/
cp /application/SpringBoot-Angular7-ShoppingCart/frontend/nginx/default.conf /etc/nginx/conf.d/default.conf

# Update Nginx Config
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
echo -e 'user  nginx;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  \x27$remote_addr - $remote_user [$time_local] "$request"\x27
                      \x27$status $body_bytes_sent "$http_referer"\x27
                      \x27"$http_user_agent" "$http_x_forwarded_for"\x27;
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  65;
    #gzip  on;
    include /etc/nginx/conf.d/*.conf;
}' > /etc/nginx/nginx.conf

# Start Nginx
systemctl enable nginx
systemctl start nginx
