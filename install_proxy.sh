#!/bin/bash

# ==============================================================================
# SKRIP FINAL - INSTALASI PROXY NGINX UNTUK FIVEM DI UBUNTU 20.04
# Dibuat untuk memastikan semua prompt input bekerja dengan benar.
# ==============================================================================

# -- FUNGSI UNTUK MENCETAK PESAN --
print_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

print_success() {
    echo -e "\e[32m[SUKSES]\e[0m $1"
}

print_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
1>&2
}

# 1. Verifikasi hak akses root
if [ "$(id -u)" != "0" ]; then
   print_error "Skrip ini harus dijalankan sebagai root. Gunakan 'sudo bash nama_skrip.sh'"
   exit 1
fi

# 2. Instalasi Nginx dari repositori resmi
install_nginx() {
    print_info "Memulai instalasi Nginx..."
    
    # Instal dependensi dasar
    apt-get update >/dev/null 2>&1
    apt-get install -y gnupg2 lsb-release software-properties-common wget curl >/dev/null 2>&1
    
    OS_CODENAME=$(lsb_release -cs)
    
    # Tambahkan kunci GPG resmi Nginx (Otomatis menimpa file yang ada)
    print_info "Menambahkan kunci GPG Nginx..."
    curl -fsSL http://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    
    # Tambahkan repositori Nginx
    print_info "Menambahkan repositori Nginx..."
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu/ $OS_CODENAME nginx" | tee /etc/apt/sources.list.d/nginx.list >/dev/null

    # Instal Nginx
    print_info "Menginstal Nginx..."
    apt-get update >/dev/null 2>&1
    apt-get install -y nginx >/dev/null 2>&1
    systemctl enable nginx >/dev/null 2>&1
    systemctl start nginx
    
    print_success "Instalasi Nginx selesai."
}

# Jalankan fungsi instalasi Nginx
install_nginx

# 3. Bersihkan konfigurasi Nginx sebelumnya
print_info "Membersihkan konfigurasi default Nginx..."
rm -f /etc/nginx/conf.d/default.conf
mkdir -p /etc/nginx/ssl

# ==============================================================================
# BAGIAN INPUT DATA PENGGUNA - HARAP PERHATIKAN DI SINI
# ==============================================================================
echo ""
print_info "Sekarang, harap masukkan data konfigurasi Anda."

echo -e "--> Masukkan alamat IP (dengan port) dari server FiveM Anda (Contoh: 1.1.1.1:30120)"
read -p "    Alamat IP & Port Server: " ip

echo -e "--> Masukkan nama domain yang akan digunakan (Contoh: play.domainanda.com)"
read -p "    Nama Domain: " domain

echo -e "--> Apakah Anda ingin membuat sertifikat SSL (HTTPS) gratis? (y/n)"
read -p "    Buat SSL Otomatis: " ssl
echo ""
# ==============================================================================

# 5. Instal Certbot untuk SSL jika diperlukan
if [[ "$ssl" == "y" || "$ssl" == "Y" ]]; then
    print_info "Pilihan SSL 'ya', menginstal Certbot..."
    apt-get install -y python3-certbot-nginx >/dev/null 2>&1
fi

# 6. Unduh file konfigurasi Nginx
print_info "Mengunduh file konfigurasi proxy..."
wget -q https://raw.githubusercontent.com/MathiAs2Pique/Fivem-Proxy-Install.sh/main/files/nginx.conf -O /etc/nginx/nginx.conf
wget -q https://raw.githubusercontent.com/MathiAs2Pique/Fivem-Proxy-Install.sh/main/files/stream.conf -O /etc/nginx/stream.conf
wget -q https://raw.githubusercontent.com/MathiAs2Pique/Fivem-Proxy-Install.sh/main/files/web.conf -O /etc/nginx/web.conf

# 7. Ganti placeholder di file konfigurasi dengan input pengguna
print_info "Menerapkan konfigurasi kustom..."
sed -i "s/ip_goes_here/$ip/g" /etc/nginx/nginx.conf
sed -i "s/ip_goes_here/$ip/g" /etc/nginx/stream.conf
sed -i "s/server_name_goes_here/$domain/g" /etc/nginx/web.conf

# 8. Buat sertifikat SSL jika diperlukan
if [[ "$ssl" == "y" || "$ssl" == "Y" ]]; then
    print_info "Membuat sertifikat SSL untuk domain $domain..."
    systemctl stop nginx
    # Menjalankan certbot
    certbot certonly --nginx -d $domain --non-interactive --agree-tos --register-unsafely-without-email
    
    # Memeriksa apakah sertifikat berhasil dibuat
    if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        print_info "Menyalin file sertifikat..."
        cp "/etc/letsencrypt/live/$domain/fullchain.pem" /etc/nginx/ssl/fullchain.pem
        cp "/etc/letsencrypt/live/$domain/privkey.pem" /etc/nginx/ssl/privkey.pem
        
        print_info "Mengaktifkan SSL di konfigurasi web..."
        sed -i 's/listen 80;/listen 443 ssl http2;/g' /etc/nginx/web.conf
        sed -i 's/# ssl_certificate/ssl_certificate/g' /etc/nginx/web.conf
        sed -i 's/# ssl_certificate_key/ssl_certificate_key/g' /etc/nginx/web.conf
    else
        print_error "Pembuatan sertifikat SSL gagal. Silakan periksa apakah domain Anda sudah mengarah ke IP server ini."
    fi
fi

# 9. Mulai ulang Nginx untuk menerapkan semua perubahan
print_info "Memulai ulang Nginx untuk menerapkan semua perubahan..."
systemctl restart nginx

# 10. Selesai
echo ""
print_success "--- INSTALASI SELESAI! ---"
if [[ "$ssl" == "y" || "$ssl" == "Y" ]]; then
    echo "Anda sekarang dapat terhubung ke server Anda menggunakan: connect https://$domain"
else
    echo "Anda sekarang dapat terhubung ke server Anda menggunakan: connect http://$domain"
fi

exit 0
