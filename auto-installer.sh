#!/bin/bash

# تحديث النظام وترقية الحزم
sudo apt update
sudo apt upgrade -y

# تثبيت المتطلبات الأساسية
sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev

# تحميل Nginx و RTMP module
cd /usr/local/src
sudo git clone https://github.com/nginx/nginx.git
sudo git clone https://github.com/arut/nginx-rtmp-module.git

# تثبيت Nginx مع إضافة وحدة RTMP
cd nginx
sudo ./auto/configure --add-module=../nginx-rtmp-module
sudo make
sudo make install

# طلب معلومات من المستخدم
read -p "أدخل اسم النطاق الخاص بك (مثلاً: example.com): " DOMAIN
read -p "أدخل البريد الإلكتروني لشهادة SSL: " EMAIL

# تكوين Nginx
NGINX_CONF="/usr/local/nginx/conf/nginx.conf"
sudo tee $NGINX_CONF > /dev/null <<EOL
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
        server_name $DOMAIN;

        # إعادة توجيه HTTP إلى HTTPS
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
            # التحقق من الدومين المرجعي
            # if (\$http_referer !~* ^https?://(www\.)?$DOMAIN) {
            #     return 403;
            # }

            # or
            # valid_referers none blocked $DOMAIN *.${DOMAIN} another_domain.com;
            # if (\$invalid_referer) {return 403;}
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

            # إعدادات HLS
            hls on;
            hls_path /usr/local/nginx/html/hls;
            hls_fragment 3s;
            hls_playlist_length 60s;

            # يتيح لنا استبدال الأجزاء من المسار باسم التدفق
            hls_nested off;

            # إعدادات البث بجودة واحدة (512k)
            # hls_variant _medium BANDWIDTH=512000;

            # تنفيذ ffmpeg لتحويل الفيديو إلى جودة واحدة (512k)
            # exec ffmpeg -i rtmp://localhost/live/\$name \
            #     -codec:v libx264 -b:v 512k -maxrate 512k -bufsize 1024k -vf "scale=w=1280:h=720:force_original_aspect_ratio=decrease" \
            #     -codec:a aac -b:a 128k \
            #     -f flv rtmp://localhost/hls/\$name_medium;
        }
    }
}
EOL

# تثبيت Certbot وتكوين SSL
sudo apt install -y certbot python3-certbot-nginx

# طلب شهادة SSL وتكوين Nginx
sudo certbot --nginx -d $DOMAIN -m $EMAIL --agree-tos --no-eff-email

echo "تم إعداد Nginx مع وحدة RTMP، تكوين ملف nginx.conf بنجاح، وتثبيت شهادة SSL."
