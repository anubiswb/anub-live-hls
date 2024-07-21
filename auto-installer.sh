#!/bin/bash

# Ask for the domain and email
read -p "Enter your domain: " domain
read -p "Enter your email for SSL certificate: " email

# Create a directory to store the script files
mkdir anub-live-hls
cd anub-live-hls

# Install required packages
echo "Updating package lists and installing required packages..."
sudo apt-get update
sudo apt-get install wget unzip software-properties-common dpkg-dev git make gcc automake build-essential zlib1g-dev libpcre3 libpcre3-dev libssl-dev libxslt1-dev libxml2-dev libgd-dev libgeoip-dev libgoogle-perftools-dev libperl-dev pkg-config autotools-dev -y

# Download and install Nginx with RTMP module
echo "Downloading and installing Nginx with RTMP module..."
wget https://nginx.org/download/nginx-1.22.0.tar.gz
tar -zxvf nginx-1.22.0.tar.gz
git clone https://github.com/arut/nginx-rtmp-module.git
cd nginx-1.22.0
./configure --add-module=../nginx-rtmp-module --with-http_ssl_module
make
sudo make install
cd ..

# Configure Nginx
echo "Configuring Nginx..."
sudo tee /usr/local/nginx/conf/nginx.conf <<EOL
worker_processes auto;

events {
    worker_connections 1024;
    multi_accept on;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    server {
        listen 80;
        server_name $domain;

        # Redirect HTTP to HTTPS
        return 301 https://\$host\$request_uri;

        location / {
            root   html;
            index  index.html index.htm;
        }

        location /hls/ {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /usr/local/nginx/html;
            add_header Cache-Control no-cache;
        }
    }
}

rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        application live {
            live on;
            record off;

            # HLS settings
            hls on;
            hls_path /usr/local/nginx/html/hls;
            hls_fragment 3s;
            hls_playlist_length 60s;
            hls_nested off;
        }
    }
}
EOL

# Install FFmpeg
echo "Downloading and installing FFmpeg..."
git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
cd ffmpeg
./configure
make
sudo make install
cd ..

# Install and configure Certbot for SSL
echo "Installing Certbot and configuring SSL certificate..."
sudo apt-get install certbot python3-certbot-nginx -y
sudo certbot --nginx -d $domain --email $email --agree-tos --non-interactive

# Start Nginx
echo "Starting Nginx..."
sudo /usr/local/nginx/sbin/nginx

echo "Installation and configuration completed."
