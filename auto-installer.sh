#!/bin/bash

# مطالبة المستخدم لإدخال اسم النطاق وعنوان البريد الإلكتروني
read -p "Enter your domain name (e.g., example.com): " domain
read -p "Enter your email address for SSL certificate: " email

# تحديث النظام وترقية الحزم
sudo apt update
sudo apt upgrade -y

# تثبيت الحزم الأساسية
sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev git

# تثبيت Certbot و Nginx Plugin للحصول على شهادة SSL
sudo apt install -y certbot python3-certbot-nginx

# تنزيل وتثبيت Nginx مع وحدة RTMP
cd /usr/local/src
sudo git clone https://github.com/nginx/nginx.git
sudo git clone https://github.com/arut/nginx-rtmp-module.git

cd nginx
sudo ./auto/configure --add-module=../nginx-rtmp-module
sudo make
sudo make install

# إعداد ملف التكوين لـ Nginx
sudo tee /usr/local/nginx/conf/nginx.conf > /dev/null <<EOL
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
        server_name $domain;    # استبدل بـ النطاق الذي أدخله المستخدم

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
#            if (\$http_referer !~* ^https?://(www\.)?$domain) {
  #              return 403;
 #           }
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


   
        }
    }
}
EOL

# بدء وتشغيل Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# الحصول على شهادة SSL باستخدام Certbot
sudo certbot --nginx -d $domain -m $email --agree-tos --non-interactive

# إعادة تشغيل Nginx لتطبيق التعديلات
sudo systemctl restart nginx

echo "تثبيت Nginx مع وحدة RTMP وتكوين SSL تم بنجاح!"
