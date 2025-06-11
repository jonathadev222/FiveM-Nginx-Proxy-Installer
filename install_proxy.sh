#!/bin/bash

# ==============================================================================
# Skrip Instalasi Proxy Nginx untuk FiveM di Ubuntu 20.04
# ==============================================================================

# 1. Verifikasi hak akses root
if [ "$(id -u)" != "0" ]; then
   echo "Skrip ini harus dijalankan sebagai root. Coba gunakan 'sudo bash nama_skrip.sh'" 1>&2
   exit 1
fi

# 2. Instalasi Nginx dari repositori resmi
install_nginx() {
    echo "--- Memulai instalasi Nginx ---"
    
    # Perbarui daftar paket dan instal dependensi yang diperlukan
    apt-get update
    apt-get install -y gnupg2 lsb-release software-properties-common wget curl

    # Dapatkan nama kode rilis Ubuntu (contoh: focal)
    OS_CODENAME=$(lsb_release -cs)

    # Tambahkan kunci GPG resmi Nginx (metode modern dan aman)
    echo "Menambahkan kunci GPG Nginx..."
    curl -fsSL http://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg

    # Tambahkan repositori Nginx Mainline
    echo "Menambahkan repositori Nginx..."
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu/ $OS_CODENAME nginx" | tee /etc/apt/sources.list.d/nginx.list
    
    # Perbarui daftar paket lagi dan instal Nginx
    echo "Menginstal Nginx..."
    apt-get update
    apt-get install -y nginx
    
    # Aktifkan dan jalankan Nginx saat boot
    systemctl enable nginx
    systemctl start nginx
    
    echo "--- Instalasi Nginx selesai ---"
}

# Jalankan fungsi instalasi Nginx
install_nginx

# 3. Bersihkan konfigurasi Nginx sebelumnya
echo "Membersihkan konfigurasi default Nginx..."
rm -f /etc/nginx/conf.d/default.conf
mkdir -p /etc/nginx/ssl

# 4. Ambil input dari pengguna
echo -e "\nSilakan masukkan alamat IP (dengan port) dari server FiveM Anda (Contoh: 1.1.1.1:30120)"
read -p "Alamat IP & Port Server: " ip

echo "Silakan masukkan nama domain yang akan digunakan (Contoh: play.domainanda.com)"
read -p "Nama Domain: " domain

echo "Apakah Anda ingin membuat sertifikat SSL (HTTPS) secara otomatis? (y/n)"
read -p "Buat SSL Otomatis: " ssl

# 5. Instal Certbot untuk SSL jika diperlukan
if [[ "$ssl" == "y" || "$ssl" == "Y" ]]; then
    echo "Menginstal Certbot untuk manajemen SSL..."
    apt-get install -y python3-certbot-nginx
fi

# 6. Unduh file konfigurasi Nginx
echo "Mengunduh file konfigurasi proxy..."
wget https://raw.githubusercontent.com/MathiAs2Pique/Fivem-Proxy-Install.sh/main/files/nginx.conf -O /etc/nginx/nginx.conf
wget https://raw.githubusercontent.com/MathiAs2Pique/Fivem-Proxy-Install.sh/main/files/stream.conf -O /etc/nginx/stream.conf
wget https://raw.githubusercontent.com/MathiAs2Pique/Fivem-Proxy-Install.sh/main/files/web.conf -O /etc/nginx/web.conf

# 7. Ganti placeholder di file konfigurasi dengan input pengguna
echo "Menerapkan konfigurasi kustom..."
sed -i "s/ip_goes_here/$ip/g" /etc/nginx/nginx.conf
sed -i "s/ip_goes_here/$ip/g" /etc/nginx/stream.conf
sed -i "s/server_name_goes_here/$domain/g" /etc/nginx/web.conf

# 8. Buat sertifikat SSL jika diperlukan
if [[ "$ssl" == "y" || "$ssl" == "Y" ]]; then
    echo -e "\nMembuat sertifikat SSL untuk $domain..."
    # Hentikan Nginx sementara agar Certbot dapat memverifikasi domain
    systemctl stop nginx
    
    # Jalankan Certbot tanpa interaksi.
    # Catatan: Opsi --register-unsafely-without-email digunakan untuk otomatisasi.
    # Anda tidak akan menerima notifikasi kedaluwarsa email dari Let's Encrypt.
    certbot certonly --nginx -d $domain --non-interactive --agree-tos --register-unsafely-without-email
    
    # Salin file sertifikat ke direktori SSL Nginx
    echo "Menyalin file sertifikat..."
    cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/nginx/ssl/fullchain.pem
    cp /etc/letsencrypt/live/$domain/privkey.pem /etc/nginx/ssl/privkey.pem
    
    # Sesuaikan file web.conf untuk menggunakan SSL (HTTPS)
    echo "Mengaktifkan SSL di konfigurasi web..."
    sed -i 's/listen 80;/listen 443 ssl http2;/g' /etc/nginx/web.conf
    sed -i 's/# ssl_certificate/ssl_certificate/g' /etc/nginx/web.conf
    sed -i 's/# ssl_certificate_key/ssl_certificate_key/g' /etc/nginx/web.conf
fi

# 9. Mulai ulang Nginx untuk menerapkan semua perubahan
echo "Memulai ulang Nginx untuk menerapkan semua perubahan..."
systemctl restart nginx

# 10. Selesai
echo -e "\n\e[32m--- Instalasi Selesai! ---\e[0m"
if [[ "$ssl" == "y" || "$ssl" == "Y" ]]; then
    echo "Anda sekarang dapat terhubung ke server Anda menggunakan: connect https://$domain"
else
    echo "Anda sekarang dapat terhubung ke server Anda menggunakan: connect http://$domain"
fi
echo "Pastikan untuk memeriksa file server.cfg di repositori untuk konfigurasi sisi server."
echo "Repositori asli: https://github.com/MathiAs2Pique/Fivem-Proxy-Install.sh"

exit 0