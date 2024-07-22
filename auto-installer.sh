#!/bin/bash

# تحديث النظام وتثبيت الحزم الضرورية
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev wget git certbot python3-certbot-nginx

# تنزيل Nginx وإصداره
wget http://nginx.org/download/nginx-1.18.0.tar.gz
tar zxvf nginx-1.18.0.tar.gz

# تنزيل وحدة RTMP
git clone https://github.com/arut/nginx-rtmp-module.git

# بناء وتثبيت Nginx مع وحدة RTMP
cd nginx-1.18.0
./configure --add-module=../nginx-rtmp-module --with-http_ssl_module
make
sudo make install

# إعداد Nginx
sudo cp /usr/local/nginx/conf/nginx.conf /usr/local/nginx/conf/nginx.conf.bak
sudo tee /usr/local/nginx/conf/nginx.conf <<EOF
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;

        location / {
            root   html;
            index  index.html index.htm;
        }

        location /hls {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /var/www;
            add_header Cache-Control no-cache;
            valid_referers none blocked localhost server_names ~\.example\.com$;
            if (\$invalid_referer) {
                return 403;
            }
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

            hls on;
            hls_path /var/www/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            hls_continuous on;
            hls_cleanup on;
        }
    }
}
EOF

# إنشاء دليل للبث وتحديد الأذونات المناسبة
sudo mkdir -p /var/www/hls
sudo chown -R www-data:www-data /var/www/hls

# إعداد خدمة النظام لبدء وإدارة Nginx
sudo tee /etc/systemd/system/nginx.service <<EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# تفعيل وبدء خدمة Nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# طلب الدومين وعنوان البريد الإلكتروني للحصول على شهادة SSL
read -p "Enter your domain name (e.g., example.com): " domain
read -p "Enter your email address for SSL certificate: " email

# الحصول على شهادة SSL باستخدام Let's Encrypt
sudo certbot --nginx -d $domain --email $email --agree-tos --non-interactive

# تعديل إعدادات Nginx لاستخدام SSL
sudo tee /usr/local/nginx/conf/nginx.conf <<EOF
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 80;
        server_name $domain;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen       443 ssl;
        server_name  $domain;

        ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers on;
        ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        location / {
            root   html;
            index  index.html index.htm;
        }

        location /hls {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /var/www;
            add_header Cache-Control no-cache;
            valid_referers none blocked localhost server_names ~\.$domain$;
            if (\$invalid_referer) {
                return 403;
            }
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

            hls on;
            hls_path /var/www/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            hls_continuous on;
            hls_cleanup on;
        }
    }
}
EOF

# إعادة تحميل Nginx لتطبيق التغييرات
sudo systemctl reload nginx

echo "Nginx with RTMP module and HLS setup is complete. SSL certificate has been configured for $domain."
