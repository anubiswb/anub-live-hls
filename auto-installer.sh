#!/bin/bash

# Ask for the domain and email
read -p "Enter your domain: " domain
read -p "Enter your email for SSL certificate: " email

# Create a directory to store the script files
mkdir auto-install-livestream-server-hls
cd auto-install-livestream-server-hls

# Download necessary files from their official GitHub repositories
echo "Downloading files from GitHub..."

# Download and install Nginx with RTMP module
echo "Installing Nginx with RTMP module..."
git clone https://github.com/arut/nginx-rtmp-module.git
wget https://nginx.org/download/nginx-1.22.0.tar.gz
tar -zxvf nginx-1.22.0.tar.gz
cd nginx-1.22.0
./configure --add-module=../nginx-rtmp-module --with-http_ssl_module
make
sudo make install
cd ..

# Download and install FFmpeg
echo "Installing FFmpeg..."
git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
cd ffmpeg
./configure
make
sudo make install
cd ..

# Install Certbot for SSL
echo "Installing Certbot and configuring SSL certificate..."
sudo apt-get update
sudo apt-get install certbot python3-certbot-nginx -y
sudo certbot --nginx -d $domain --email $email --agree-tos --non-interactive

echo "Installation and configuration completed."
