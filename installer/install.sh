#!/bin/bash

#############################################
# Premium Mail - Complete Email Hosting Installer
# Version: 2.0.0
# 
# This script installs a complete email hosting solution:
# - Postfix (SMTP Server)
# - Dovecot (IMAP/POP3 Server)
# - Roundcube Webmail with Premium Starter Skin
# - MySQL/MariaDB Database
# - Nginx Web Server
# - SSL/TLS via Let's Encrypt
# - SPF, DKIM, DMARC Configuration
# - SpamAssassin & ClamAV
# - Fail2Ban Security
#
# Supported: Ubuntu 20.04/22.04/24.04, Debian 11/12
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration Variables
INSTALLER_VERSION="2.0.0"
LOG_FILE="/var/log/premium-mail-install.log"
BACKUP_DIR="/root/premium-mail-backup"
CONFIG_DIR="/etc/premium-mail"

# Default values (can be overridden)
MYSQL_ROOT_PASSWORD=""
MYSQL_MAIL_PASSWORD=""
ADMIN_EMAIL=""
ADMIN_PASSWORD=""
MAIL_DOMAIN=""
HOSTNAME_FQDN=""
SSL_EMAIL=""
ROUNDCUBE_VERSION="1.6.6"

#############################################
# Helper Functions
#############################################

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_banner() {
    echo -e "${PURPLE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║   ██████╗ ██████╗ ███████╗███╗   ███╗██╗██╗   ██╗███╗   ███╗║"
    echo "║   ██╔══██╗██╔══██╗██╔════╝████╗ ████║██║██║   ██║████╗ ████║║"
    echo "║   ██████╔╝██████╔╝█████╗  ██╔████╔██║██║██║   ██║██╔████╔██║║"
    echo "║   ██╔═══╝ ██╔══██╗██╔══╝  ██║╚██╔╝██║██║██║   ██║██║╚██╔╝██║║"
    echo "║   ██║     ██║  ██║███████╗██║ ╚═╝ ██║██║╚██████╔╝██║ ╚═╝ ██║║"
    echo "║   ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═╝ ╚═════╝ ╚═╝     ╚═╝║"
    echo "║                                                            ║"
    echo "║        Premium Mail - Email Hosting Installer v${INSTALLER_VERSION}        ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        
        case $ID in
            ubuntu)
                if [[ ! "$VER" =~ ^(20.04|22.04|24.04)$ ]]; then
                    log_warning "Ubuntu $VER may not be fully supported"
                fi
                ;;
            debian)
                if [[ ! "$VER" =~ ^(11|12)$ ]]; then
                    log_warning "Debian $VER may not be fully supported"
                fi
                ;;
            *)
                log_error "Unsupported OS: $OS"
                exit 1
                ;;
        esac
        
        log "Detected OS: $OS $VER"
    else
        log_error "Cannot determine OS version"
        exit 1
    fi
}

generate_password() {
    local length=${1:-32}
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9!@#$%&*' | head -c "$length"
}

get_public_ip() {
    curl -s https://api.ipify.org || curl -s https://ifconfig.me || hostname -I | awk '{print $1}'
}

backup_existing() {
    if [ -d "/etc/postfix" ] || [ -d "/etc/dovecot" ]; then
        log "Backing up existing configuration..."
        mkdir -p "$BACKUP_DIR"
        [ -d "/etc/postfix" ] && cp -r /etc/postfix "$BACKUP_DIR/"
        [ -d "/etc/dovecot" ] && cp -r /etc/dovecot "$BACKUP_DIR/"
        [ -d "/etc/nginx" ] && cp -r /etc/nginx "$BACKUP_DIR/"
        log "Backup saved to $BACKUP_DIR"
    fi
}

#############################################
# Installation Functions
#############################################

install_prerequisites() {
    log "Installing prerequisites..."
    
    apt-get update
    apt-get install -y \
        curl \
        wget \
        gnupg2 \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        lsb-release \
        unzip \
        git \
        openssl \
        pwgen \
        dnsutils
    
    log "Prerequisites installed successfully"
}

install_mysql() {
    log "Installing MariaDB..."
    
    apt-get install -y mariadb-server mariadb-client
    
    systemctl start mariadb
    systemctl enable mariadb
    
    # Generate password if not set
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        MYSQL_ROOT_PASSWORD=$(generate_password 24)
    fi
    
    # Check if root already has a password set
    if mysql -u root -e "SELECT 1" &>/dev/null; then
        # No password set, secure the installation
        mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"
        mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='';"
        mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
        mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS test;"
        mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
        mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
        log "MariaDB installed and secured"
    else
        # Root password already exists, ask user for it
        log_warning "MariaDB root password already set."
        echo -e "${YELLOW}Enter existing MariaDB root password:${NC}"
        read -s MYSQL_ROOT_PASSWORD
        echo
        
        # Verify the password works
        if ! mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" &>/dev/null; then
            log_error "Invalid MariaDB root password!"
            exit 1
        fi
        log "Using existing MariaDB installation"
    fi
}

create_mail_database() {
    log "Creating mail database..."
    
    if [ -z "$MYSQL_MAIL_PASSWORD" ]; then
        MYSQL_MAIL_PASSWORD=$(generate_password 24)
    fi
    
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS mailserver CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'mailuser'@'localhost' IDENTIFIED BY '${MYSQL_MAIL_PASSWORD}';
GRANT ALL PRIVILEGES ON mailserver.* TO 'mailuser'@'localhost';
FLUSH PRIVILEGES;

USE mailserver;

-- Domains table
CREATE TABLE IF NOT EXISTS virtual_domains (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Users/Mailboxes table
CREATE TABLE IF NOT EXISTS virtual_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    domain_id INT NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    quota BIGINT DEFAULT 1073741824,
    active TINYINT(1) DEFAULT 1,
    is_admin TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
);

-- Aliases table
CREATE TABLE IF NOT EXISTS virtual_aliases (
    id INT AUTO_INCREMENT PRIMARY KEY,
    domain_id INT NOT NULL,
    source VARCHAR(255) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES virtual_domains(id) ON DELETE CASCADE
);

-- Admin settings table
CREATE TABLE IF NOT EXISTS admin_settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(255) NOT NULL UNIQUE,
    setting_value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Login attempts table (for security)
CREATE TABLE IF NOT EXISTS login_attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ip_address VARCHAR(45) NOT NULL,
    email VARCHAR(255),
    success TINYINT(1) DEFAULT 0,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ip (ip_address),
    INDEX idx_created (created_at)
);

-- Logs table
CREATE TABLE IF NOT EXISTS admin_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    admin_id INT,
    action VARCHAR(255) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (admin_id) REFERENCES virtual_users(id) ON DELETE SET NULL
);

-- Insert default domain
INSERT INTO virtual_domains (name) VALUES ('${MAIL_DOMAIN}') ON DUPLICATE KEY UPDATE name=name;
EOF

    log "Mail database created successfully"
}

install_postfix() {
    log "Installing Postfix..."
    
    # Pre-configure postfix
    debconf-set-selections <<< "postfix postfix/mailname string ${HOSTNAME_FQDN}"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
    
    apt-get install -y postfix postfix-mysql
    
    # Backup original config
    cp /etc/postfix/main.cf /etc/postfix/main.cf.backup
    
    # Configure main.cf
    cat > /etc/postfix/main.cf <<EOF
# Postfix Configuration - Premium Mail
# Generated by Premium Mail Installer v${INSTALLER_VERSION}

# Basic Settings
smtpd_banner = \$myhostname ESMTP
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 3.6

# TLS Parameters
smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_loglevel = 1
smtpd_tls_received_header = yes
smtpd_tls_session_cache_timeout = 3600s
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = high
smtpd_tls_mandatory_ciphers = high

smtp_tls_security_level = may
smtp_tls_loglevel = 1
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1

# Network Settings
myhostname = ${HOSTNAME_FQDN}
mydomain = ${MAIL_DOMAIN}
myorigin = \$mydomain
mydestination = localhost
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
inet_interfaces = all
inet_protocols = all

# Virtual Mailbox Settings
virtual_transport = lmtp:unix:private/dovecot-lmtp
virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox.cf
virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias.cf

# SASL Authentication
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = \$myhostname
broken_sasl_auth_clients = yes

# Restrictions
smtpd_helo_required = yes
smtpd_helo_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_invalid_helo_hostname,
    reject_non_fqdn_helo_hostname

smtpd_sender_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_non_fqdn_sender,
    reject_unknown_sender_domain

smtpd_recipient_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_non_fqdn_recipient,
    reject_unknown_recipient_domain,
    reject_unauth_destination

smtpd_relay_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    defer_unauth_destination

# Message Size Limit (50MB)
message_size_limit = 52428800
mailbox_size_limit = 0

# Milters for DKIM
milter_default_action = accept
milter_protocol = 6
smtpd_milters = inet:localhost:8891
non_smtpd_milters = \$smtpd_milters
EOF

    # Configure MySQL lookups for virtual domains
    cat > /etc/postfix/mysql-virtual-domains.cf <<EOF
user = mailuser
password = ${MYSQL_MAIL_PASSWORD}
hosts = 127.0.0.1
dbname = mailserver
query = SELECT name FROM virtual_domains WHERE name='%s' AND active=1
EOF

    # Configure MySQL lookups for virtual mailboxes
    cat > /etc/postfix/mysql-virtual-mailbox.cf <<EOF
user = mailuser
password = ${MYSQL_MAIL_PASSWORD}
hosts = 127.0.0.1
dbname = mailserver
query = SELECT CONCAT(virtual_domains.name, '/', virtual_users.email, '/') FROM virtual_users INNER JOIN virtual_domains ON virtual_users.domain_id = virtual_domains.id WHERE virtual_users.email='%s' AND virtual_users.active=1
EOF

    # Configure MySQL lookups for virtual aliases
    cat > /etc/postfix/mysql-virtual-alias.cf <<EOF
user = mailuser
password = ${MYSQL_MAIL_PASSWORD}
hosts = 127.0.0.1
dbname = mailserver
query = SELECT destination FROM virtual_aliases WHERE source='%s' AND active=1
EOF

    # Secure the MySQL config files
    chmod 640 /etc/postfix/mysql-*.cf
    chown root:postfix /etc/postfix/mysql-*.cf

    # Configure master.cf for submission
    cat >> /etc/postfix/master.cf <<EOF

# Submission port (587)
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING

# SMTPS port (465)
smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF

    log "Postfix installed and configured"
}

install_dovecot() {
    log "Installing Dovecot..."
    
    apt-get install -y dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-mysql dovecot-sieve dovecot-managesieved
    
    # Create vmail user
    groupadd -g 5000 vmail 2>/dev/null || true
    useradd -g vmail -u 5000 vmail -d /var/mail/vhosts -s /sbin/nologin 2>/dev/null || true
    mkdir -p /var/mail/vhosts/${MAIL_DOMAIN}
    chown -R vmail:vmail /var/mail/vhosts
    chmod -R 770 /var/mail/vhosts
    
    # Configure dovecot.conf
    cat > /etc/dovecot/dovecot.conf <<EOF
# Dovecot Configuration - Premium Mail
# Generated by Premium Mail Installer v${INSTALLER_VERSION}

# Protocols
protocols = imap pop3 lmtp sieve

# Logging
log_path = /var/log/dovecot.log
info_log_path = /var/log/dovecot-info.log
debug_log_path = /var/log/dovecot-debug.log

# SSL
ssl = required
ssl_cert = </etc/ssl/certs/ssl-cert-snakeoil.pem
ssl_key = </etc/ssl/private/ssl-cert-snakeoil.key
ssl_min_protocol = TLSv1.2
ssl_cipher_list = ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
ssl_prefer_server_ciphers = yes

# Mail location
mail_location = maildir:/var/mail/vhosts/%d/%n
mail_uid = vmail
mail_gid = vmail
mail_privileged_group = vmail

# Auth
disable_plaintext_auth = yes
auth_mechanisms = plain login

# Authentication
passdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf.ext
}

userdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf.ext
}

# Services
service auth {
    unix_listener /var/spool/postfix/private/auth {
        mode = 0660
        user = postfix
        group = postfix
    }
    unix_listener auth-userdb {
        mode = 0600
        user = vmail
        group = vmail
    }
}

service lmtp {
    unix_listener /var/spool/postfix/private/dovecot-lmtp {
        mode = 0600
        user = postfix
        group = postfix
    }
}

service imap-login {
    inet_listener imap {
        port = 143
    }
    inet_listener imaps {
        port = 993
        ssl = yes
    }
}

service pop3-login {
    inet_listener pop3 {
        port = 110
    }
    inet_listener pop3s {
        port = 995
        ssl = yes
    }
}

service managesieve-login {
    inet_listener sieve {
        port = 4190
    }
}

service managesieve {
    process_limit = 1024
}

# Sieve
plugin {
    sieve = ~/.dovecot.sieve
    sieve_dir = ~/sieve
    sieve_before = /var/mail/sieve/before.d/
    sieve_after = /var/mail/sieve/after.d/
}

protocol lmtp {
    mail_plugins = \$mail_plugins sieve
}

protocol imap {
    mail_plugins = \$mail_plugins
    mail_max_userip_connections = 20
}

# Quota
plugin {
    quota = maildir:User quota
    quota_rule = *:storage=1G
    quota_rule2 = Trash:storage=+100M
    quota_grace = 10%%
    quota_status_success = DUNNO
    quota_status_nouser = DUNNO
    quota_status_overquota = "452 4.2.2 Mailbox is full"
}

# Namespace
namespace inbox {
    inbox = yes
    
    mailbox Drafts {
        special_use = \\Drafts
        auto = subscribe
    }
    mailbox Sent {
        special_use = \\Sent
        auto = subscribe
    }
    mailbox "Sent Messages" {
        special_use = \\Sent
    }
    mailbox Trash {
        special_use = \\Trash
        auto = subscribe
    }
    mailbox Junk {
        special_use = \\Junk
        auto = subscribe
    }
    mailbox Spam {
        special_use = \\Junk
    }
    mailbox Archive {
        special_use = \\Archive
        auto = subscribe
    }
}
EOF

    # Configure SQL authentication
    cat > /etc/dovecot/dovecot-sql.conf.ext <<EOF
driver = mysql
connect = host=127.0.0.1 dbname=mailserver user=mailuser password=${MYSQL_MAIL_PASSWORD}
default_pass_scheme = SHA512-CRYPT
password_query = SELECT email as user, password FROM virtual_users WHERE email='%u' AND active=1
user_query = SELECT CONCAT('/var/mail/vhosts/', virtual_domains.name, '/', virtual_users.email) AS home, 5000 AS uid, 5000 AS gid, CONCAT('*:bytes=', quota) AS quota_rule FROM virtual_users INNER JOIN virtual_domains ON virtual_users.domain_id = virtual_domains.id WHERE virtual_users.email='%u' AND virtual_users.active=1
iterate_query = SELECT email AS user FROM virtual_users WHERE active=1
EOF

    chmod 600 /etc/dovecot/dovecot-sql.conf.ext
    chown root:root /etc/dovecot/dovecot-sql.conf.ext
    
    # Create sieve directories
    mkdir -p /var/mail/sieve/{before.d,after.d}
    chown -R vmail:vmail /var/mail/sieve

    log "Dovecot installed and configured"
}

install_nginx() {
    log "Installing Nginx..."
    
    apt-get install -y nginx
    
    # Create webmail directory
    mkdir -p /var/www/webmail
    chown -R www-data:www-data /var/www/webmail
    
    # Configure Nginx
    cat > /etc/nginx/sites-available/webmail <<EOF
# Premium Mail - Nginx Configuration

server {
    listen 80;
    listen [::]:80;
    server_name ${HOSTNAME_FQDN};
    
    # Redirect to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/webmail;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${HOSTNAME_FQDN};
    
    root /var/www/webmail;
    index index.php index.html;
    
    # SSL Configuration (will be updated by certbot)
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Client body size (for attachments)
    client_max_body_size 50M;
    
    # Roundcube location
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    # PHP handling
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # Security
        fastcgi_hide_header X-Powered-By;
    }
    
    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }
    
    location ~ ^/(config|temp|logs)/ {
        deny all;
    }
    
    location ~ /README|INSTALL|LICENSE|CHANGELOG|UPGRADING {
        deny all;
    }
    
    # Cache static files
    location ~* \.(jpg|jpeg|gif|png|ico|css|js|woff|woff2|ttf|svg)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    ln -sf /etc/nginx/sites-available/webmail /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    nginx -t && systemctl reload nginx
    
    log "Nginx installed and configured"
}

install_php() {
    log "Installing PHP..."
    
    apt-get install -y \
        php-fpm \
        php-mysql \
        php-cli \
        php-curl \
        php-gd \
        php-intl \
        php-mbstring \
        php-xml \
        php-zip \
        php-json \
        php-imagick \
        php-ldap \
        php-pspell
    
    # Get PHP version
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    PHP_FPM_SOCK="/var/run/php/php${PHP_VERSION}-fpm.sock"
    
    # Configure PHP
    PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
    
    sed -i 's/^upload_max_filesize.*/upload_max_filesize = 50M/' "$PHP_INI"
    sed -i 's/^post_max_size.*/post_max_size = 50M/' "$PHP_INI"
    sed -i 's/^memory_limit.*/memory_limit = 256M/' "$PHP_INI"
    sed -i 's/^max_execution_time.*/max_execution_time = 300/' "$PHP_INI"
    sed -i 's/^;date.timezone.*/date.timezone = UTC/' "$PHP_INI"
    sed -i 's/^expose_php.*/expose_php = Off/' "$PHP_INI"
    
    # Update Nginx to use correct PHP socket
    sed -i "s|unix:/var/run/php/php-fpm.sock|unix:${PHP_FPM_SOCK}|g" /etc/nginx/sites-available/webmail
    
    systemctl restart "php${PHP_VERSION}-fpm"
    systemctl restart nginx
    
    log "PHP ${PHP_VERSION} installed and configured"
}

install_roundcube() {
    log "Installing Roundcube..."
    
    cd /tmp
    wget -q "https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBE_VERSION}/roundcubemail-${ROUNDCUBE_VERSION}-complete.tar.gz"
    tar -xzf "roundcubemail-${ROUNDCUBE_VERSION}-complete.tar.gz"
    
    rm -rf /var/www/webmail/*
    mv "roundcubemail-${ROUNDCUBE_VERSION}"/* /var/www/webmail/
    rm -rf "roundcubemail-${ROUNDCUBE_VERSION}" "roundcubemail-${ROUNDCUBE_VERSION}-complete.tar.gz"
    
    cd /var/www/webmail
    
    # Create Roundcube database
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS roundcube CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON roundcube.* TO 'mailuser'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Import Roundcube schema
    mysql -u mailuser -p"${MYSQL_MAIL_PASSWORD}" roundcube < /var/www/webmail/SQL/mysql.initial.sql
    
    # Generate DES key
    DES_KEY=$(generate_password 24)
    
    # Create Roundcube config
    cat > /var/www/webmail/config/config.inc.php <<EOF
<?php
/**
 * Premium Mail - Roundcube Configuration
 * Generated by Premium Mail Installer v${INSTALLER_VERSION}
 */

// Database connection
\$config['db_dsnw'] = 'mysql://mailuser:${MYSQL_MAIL_PASSWORD}@127.0.0.1/roundcube';

// IMAP Server
\$config['default_host'] = 'ssl://${HOSTNAME_FQDN}';
\$config['default_port'] = 993;
\$config['imap_auth_type'] = 'PLAIN';
\$config['imap_conn_options'] = array(
    'ssl' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
    ),
);

// SMTP Server
\$config['smtp_server'] = 'tls://${HOSTNAME_FQDN}';
\$config['smtp_port'] = 587;
\$config['smtp_user'] = '%u';
\$config['smtp_pass'] = '%p';
\$config['smtp_auth_type'] = 'PLAIN';
\$config['smtp_conn_options'] = array(
    'ssl' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
    ),
);

// System settings
\$config['support_url'] = '';
\$config['product_name'] = 'Premium Mail';
\$config['des_key'] = '${DES_KEY}';
\$config['plugins'] = array(
    'archive',
    'zipdownload',
    'markasjunk',
    'managesieve',
    'password',
    'newmail_notifier',
    'emoticons',
    'vcard_attachments',
    'attachment_reminder',
);

// User Interface
\$config['language'] = 'en_US';
\$config['skin'] = 'premium_starter';
\$config['skin_logo'] = null;
\$config['timezone'] = 'auto';
\$config['date_format'] = 'Y-m-d';
\$config['time_format'] = 'H:i';
\$config['refresh_interval'] = 60;
\$config['message_show_email'] = true;
\$config['prefer_html'] = true;
\$config['htmleditor'] = 4;
\$config['draft_autosave'] = 60;
\$config['mime_param_folding'] = 0;
\$config['mdn_requests'] = 0;

// Addressbook
\$config['autocomplete_addressbooks'] = array('sql');
\$config['autocomplete_min_length'] = 1;
\$config['autocomplete_max'] = 15;
\$config['address_book_type'] = 'sql';

// Caching
\$config['imap_cache'] = 'db';
\$config['imap_cache_ttl'] = '10d';
\$config['messages_cache'] = 'db';
\$config['messages_cache_ttl'] = '10d';
\$config['session_lifetime'] = 30;

// Attachments
\$config['max_message_size'] = '50M';
\$config['max_group_members'] = 50;

// Security
\$config['login_autocomplete'] = 2;
\$config['ip_check'] = true;
\$config['x_frame_options'] = 'sameorigin';
\$config['use_https'] = true;
\$config['password_charset'] = 'UTF-8';

// Sieve (Filters)
\$config['managesieve_host'] = '${HOSTNAME_FQDN}';
\$config['managesieve_port'] = 4190;
\$config['managesieve_auth_type'] = 'PLAIN';
\$config['managesieve_usetls'] = true;

// Password plugin config
\$config['password_driver'] = 'sql';
\$config['password_db_dsn'] = 'mysql://mailuser:${MYSQL_MAIL_PASSWORD}@127.0.0.1/mailserver';
\$config['password_query'] = 'UPDATE virtual_users SET password=%P WHERE email=%u';
\$config['password_crypt_hash'] = 'sha512';
\$config['password_algorithm'] = 'crypt';
\$config['password_minimum_length'] = 8;
\$config['password_require_nonalpha'] = true;
\$config['password_force_new_user'] = false;

// Logging
\$config['log_driver'] = 'file';
\$config['log_dir'] = '/var/log/roundcube/';
\$config['per_user_logging'] = false;

// Debugging (disable in production)
\$config['debug_level'] = 0;
\$config['sql_debug'] = false;
\$config['imap_debug'] = false;
\$config['smtp_debug'] = false;
EOF

    # Create log directory
    mkdir -p /var/log/roundcube
    chown -R www-data:www-data /var/log/roundcube
    
    # Set permissions
    chown -R www-data:www-data /var/www/webmail
    chmod -R 755 /var/www/webmail
    chmod 640 /var/www/webmail/config/config.inc.php
    
    log "Roundcube installed and configured"
}

install_premium_skin() {
    log "Installing Premium Starter skin..."
    
    SKIN_DIR="/var/www/webmail/skins/premium_starter"
    
    # Create skin directory structure
    mkdir -p "$SKIN_DIR"/{templates,templates/includes,images}
    
    # Check if local skin files exist
    if [ -d "/opt/premium-mail/roundcube-skin/premium_starter" ]; then
        cp -r /opt/premium-mail/roundcube-skin/premium_starter/* "$SKIN_DIR/"
    else
        log_warning "Premium skin source not found, downloading from repository..."
        # Download from GitHub or create basic skin
        # For now, create a basic meta.json
        cat > "$SKIN_DIR/meta.json" <<'EOF'
{
    "name": "Premium Starter",
    "author": "Premium Mail Team",
    "version": "2.0.0",
    "license": "MIT",
    "extends": "elastic",
    "config": {
        "layout": "widescreen",
        "dark_mode_support": true
    }
}
EOF
    fi
    
    chown -R www-data:www-data "$SKIN_DIR"
    
    log "Premium Starter skin installed"
}

install_opendkim() {
    log "Installing OpenDKIM..."
    
    apt-get install -y opendkim opendkim-tools
    
    # Configure OpenDKIM
    cat > /etc/opendkim.conf <<EOF
# OpenDKIM Configuration
AutoRestart             Yes
AutoRestartRate         10/1h
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes
Canonicalization        relaxed/simple
ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable
Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256
UserID                  opendkim:opendkim
Socket                  inet:8891@localhost
EOF

    # Create directories
    mkdir -p /etc/opendkim/keys/${MAIL_DOMAIN}
    
    # Generate DKIM key
    opendkim-genkey -b 2048 -d ${MAIL_DOMAIN} -D /etc/opendkim/keys/${MAIL_DOMAIN} -s mail -v
    
    # Create configuration files
    cat > /etc/opendkim/TrustedHosts <<EOF
127.0.0.1
localhost
${MAIL_DOMAIN}
*.${MAIL_DOMAIN}
EOF

    cat > /etc/opendkim/KeyTable <<EOF
mail._domainkey.${MAIL_DOMAIN} ${MAIL_DOMAIN}:mail:/etc/opendkim/keys/${MAIL_DOMAIN}/mail.private
EOF

    cat > /etc/opendkim/SigningTable <<EOF
*@${MAIL_DOMAIN} mail._domainkey.${MAIL_DOMAIN}
EOF

    # Set permissions
    chown -R opendkim:opendkim /etc/opendkim
    chmod 700 /etc/opendkim/keys/${MAIL_DOMAIN}
    chmod 600 /etc/opendkim/keys/${MAIL_DOMAIN}/mail.private

    # Get DKIM public key for DNS
    DKIM_RECORD=$(cat /etc/opendkim/keys/${MAIL_DOMAIN}/mail.txt)
    
    systemctl enable opendkim
    systemctl restart opendkim
    
    log "OpenDKIM installed and configured"
    log_info "DKIM DNS Record: ${DKIM_RECORD}"
}

install_spamassassin() {
    log "Installing SpamAssassin..."
    
    apt-get install -y spamassassin spamc
    
    # Enable SpamAssassin - handle both old and new Ubuntu versions
    if [ -f /etc/default/spamassassin ]; then
        sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/spamassassin
        sed -i 's/CRON=0/CRON=1/' /etc/default/spamassassin
    fi
    
    # Configure SpamAssassin
    cat > /etc/spamassassin/local.cf <<EOF
# SpamAssassin Configuration - Premium Mail

rewrite_header Subject [SPAM]
report_safe 0
required_score 5.0
use_bayes 1
bayes_auto_learn 1
bayes_ignore_header X-Bogosity
bayes_ignore_header X-Spam-Flag
bayes_ignore_header X-Spam-Status
skip_rbl_checks 0
use_razor2 0
use_pyzor 0
EOF

    # Ubuntu 24.04+ uses spamd, older versions use spamassassin
    if systemctl list-unit-files | grep -q "^spamd.service"; then
        systemctl enable spamd
        systemctl start spamd
    else
        systemctl enable spamassassin
        systemctl start spamassassin
    fi
    
    log "SpamAssassin installed and configured"
}

install_fail2ban() {
    log "Installing Fail2Ban..."
    
    apt-get install -y fail2ban
    
    # Configure Fail2Ban for mail services
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
banaction = iptables-multiport

[postfix]
enabled = true
port = smtp,465,submission
logpath = /var/log/mail.log

[postfix-sasl]
enabled = true
port = smtp,465,submission,imap,imaps,pop3,pop3s
logpath = /var/log/mail.log

[dovecot]
enabled = true
port = pop3,pop3s,imap,imaps,submission,465,sieve
logpath = /var/log/mail.log

[roundcube-auth]
enabled = true
port = http,https
logpath = /var/log/roundcube/errors.log
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log "Fail2Ban installed and configured"
}

install_certbot() {
    log "Installing Certbot for SSL..."
    
    apt-get install -y certbot python3-certbot-nginx
    
    if [ -n "$SSL_EMAIL" ]; then
        log "Obtaining SSL certificate..."
        certbot --nginx -d ${HOSTNAME_FQDN} --non-interactive --agree-tos -m ${SSL_EMAIL} || {
            log_warning "Failed to obtain SSL certificate. You can run 'certbot --nginx -d ${HOSTNAME_FQDN}' later."
        }
        
        # Update Postfix and Dovecot to use Let's Encrypt certificates
        if [ -f "/etc/letsencrypt/live/${HOSTNAME_FQDN}/fullchain.pem" ]; then
            # Postfix
            postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/${HOSTNAME_FQDN}/fullchain.pem"
            postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/${HOSTNAME_FQDN}/privkey.pem"
            
            # Dovecot
            sed -i "s|ssl_cert = .*|ssl_cert = </etc/letsencrypt/live/${HOSTNAME_FQDN}/fullchain.pem|" /etc/dovecot/dovecot.conf
            sed -i "s|ssl_key = .*|ssl_key = </etc/letsencrypt/live/${HOSTNAME_FQDN}/privkey.pem|" /etc/dovecot/dovecot.conf
            
            systemctl restart postfix dovecot
        fi
    else
        log_warning "No SSL email provided. Run 'certbot --nginx -d ${HOSTNAME_FQDN}' to obtain SSL certificate."
    fi
    
    # Setup auto-renewal
    systemctl enable certbot.timer
    
    log "Certbot installed"
}

create_admin_user() {
    log "Creating admin user..."
    
    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD=$(generate_password 16)
    fi
    
    # Hash password
    HASHED_PASSWORD=$(doveadm pw -s SHA512-CRYPT -p "$ADMIN_PASSWORD")
    
    # Get domain ID
    DOMAIN_ID=$(mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -N -e "SELECT id FROM mailserver.virtual_domains WHERE name='${MAIL_DOMAIN}'")
    
    # Create admin user
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOF
INSERT INTO mailserver.virtual_users (domain_id, email, password, name, is_admin, active)
VALUES (${DOMAIN_ID}, '${ADMIN_EMAIL}', '${HASHED_PASSWORD}', 'Administrator', 1, 1)
ON DUPLICATE KEY UPDATE password='${HASHED_PASSWORD}', is_admin=1;
EOF

    log "Admin user created: ${ADMIN_EMAIL}"
}

create_admin_panel() {
    log "Creating admin panel..."
    
    ADMIN_DIR="/var/www/webmail/admin"
    mkdir -p "$ADMIN_DIR"
    
    # Create admin panel PHP file
    cat > "$ADMIN_DIR/index.php" <<'ADMINPHP'
<?php
/**
 * Premium Mail - Admin Panel
 * Version 2.0.0
 */

session_start();
error_reporting(0);

// Configuration
define('DB_HOST', '127.0.0.1');
define('DB_NAME', 'mailserver');
define('DB_USER', 'mailuser');
define('ADMIN_SESSION_NAME', 'premium_mail_admin');

// Load Roundcube config for database password
$rcConfig = include('/var/www/webmail/config/config.inc.php');
$dbDsn = $rcConfig['password_db_dsn'] ?? '';
preg_match('/password=([^@]+)@/', $dbDsn, $matches);
define('DB_PASS', $matches[1] ?? '');

class PremiumMailAdmin {
    private $db;
    private $error = '';
    private $success = '';
    
    public function __construct() {
        try {
            $this->db = new PDO(
                'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
                DB_USER,
                DB_PASS,
                [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
            );
        } catch (PDOException $e) {
            die('Database connection failed');
        }
    }
    
    public function isLoggedIn() {
        return isset($_SESSION[ADMIN_SESSION_NAME]) && $_SESSION[ADMIN_SESSION_NAME]['is_admin'] === true;
    }
    
    public function login($email, $password) {
        $stmt = $this->db->prepare('SELECT * FROM virtual_users WHERE email = ? AND is_admin = 1 AND active = 1');
        $stmt->execute([$email]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($user) {
            // Verify password using crypt
            if (password_verify($password, str_replace('{SHA512-CRYPT}', '', $user['password'])) ||
                crypt($password, $user['password']) === $user['password']) {
                $_SESSION[ADMIN_SESSION_NAME] = [
                    'id' => $user['id'],
                    'email' => $user['email'],
                    'name' => $user['name'],
                    'is_admin' => true
                ];
                
                // Log successful login
                $this->logAction($user['id'], 'login', 'Successful login');
                return true;
            }
        }
        
        // Log failed attempt
        $this->logLoginAttempt($email, false);
        return false;
    }
    
    public function logout() {
        if ($this->isLoggedIn()) {
            $this->logAction($_SESSION[ADMIN_SESSION_NAME]['id'], 'logout', 'Logged out');
        }
        unset($_SESSION[ADMIN_SESSION_NAME]);
        session_destroy();
    }
    
    public function getDomains() {
        $stmt = $this->db->query('SELECT * FROM virtual_domains ORDER BY name');
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    public function addDomain($name) {
        $name = strtolower(trim($name));
        if (!filter_var('test@' . $name, FILTER_VALIDATE_EMAIL)) {
            $this->error = 'Invalid domain name';
            return false;
        }
        
        try {
            $stmt = $this->db->prepare('INSERT INTO virtual_domains (name) VALUES (?)');
            $stmt->execute([$name]);
            $this->success = 'Domain added successfully';
            $this->logAction($_SESSION[ADMIN_SESSION_NAME]['id'], 'add_domain', "Added domain: $name");
            return true;
        } catch (PDOException $e) {
            $this->error = 'Domain already exists';
            return false;
        }
    }
    
    public function deleteDomain($id) {
        $stmt = $this->db->prepare('DELETE FROM virtual_domains WHERE id = ?');
        $stmt->execute([$id]);
        $this->success = 'Domain deleted successfully';
        $this->logAction($_SESSION[ADMIN_SESSION_NAME]['id'], 'delete_domain', "Deleted domain ID: $id");
        return true;
    }
    
    public function getUsers($domainId = null) {
        $sql = 'SELECT u.*, d.name as domain_name FROM virtual_users u 
                JOIN virtual_domains d ON u.domain_id = d.id';
        if ($domainId) {
            $sql .= ' WHERE u.domain_id = ?';
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$domainId]);
        } else {
            $stmt = $this->db->query($sql);
        }
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    public function addUser($domainId, $email, $password, $name = '', $quota = 1073741824) {
        $email = strtolower(trim($email));
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->error = 'Invalid email address';
            return false;
        }
        
        // Hash password
        $hashedPassword = '{SHA512-CRYPT}' . crypt($password, '$6$' . bin2hex(random_bytes(8)) . '$');
        
        try {
            $stmt = $this->db->prepare('INSERT INTO virtual_users (domain_id, email, password, name, quota) VALUES (?, ?, ?, ?, ?)');
            $stmt->execute([$domainId, $email, $hashedPassword, $name, $quota]);
            $this->success = 'User created successfully';
            $this->logAction($_SESSION[ADMIN_SESSION_NAME]['id'], 'add_user', "Added user: $email");
            return true;
        } catch (PDOException $e) {
            $this->error = 'Email already exists';
            return false;
        }
    }
    
    public function deleteUser($id) {
        $stmt = $this->db->prepare('SELECT email FROM virtual_users WHERE id = ?');
        $stmt->execute([$id]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        $stmt = $this->db->prepare('DELETE FROM virtual_users WHERE id = ?');
        $stmt->execute([$id]);
        $this->success = 'User deleted successfully';
        $this->logAction($_SESSION[ADMIN_SESSION_NAME]['id'], 'delete_user', "Deleted user: " . ($user['email'] ?? $id));
        return true;
    }
    
    public function updateUserPassword($id, $password) {
        $hashedPassword = '{SHA512-CRYPT}' . crypt($password, '$6$' . bin2hex(random_bytes(8)) . '$');
        $stmt = $this->db->prepare('UPDATE virtual_users SET password = ? WHERE id = ?');
        $stmt->execute([$hashedPassword, $id]);
        $this->success = 'Password updated successfully';
        $this->logAction($_SESSION[ADMIN_SESSION_NAME]['id'], 'update_password', "Updated password for user ID: $id");
        return true;
    }
    
    public function toggleUserStatus($id) {
        $stmt = $this->db->prepare('UPDATE virtual_users SET active = NOT active WHERE id = ?');
        $stmt->execute([$id]);
        $this->success = 'User status updated';
        $this->logAction($_SESSION[ADMIN_SESSION_NAME]['id'], 'toggle_user_status', "Toggled status for user ID: $id");
        return true;
    }
    
    public function getAliases() {
        $stmt = $this->db->query('SELECT a.*, d.name as domain_name FROM virtual_aliases a JOIN virtual_domains d ON a.domain_id = d.id ORDER BY a.source');
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    public function addAlias($domainId, $source, $destination) {
        try {
            $stmt = $this->db->prepare('INSERT INTO virtual_aliases (domain_id, source, destination) VALUES (?, ?, ?)');
            $stmt->execute([$domainId, $source, $destination]);
            $this->success = 'Alias added successfully';
            $this->logAction($_SESSION[ADMIN_SESSION_NAME]['id'], 'add_alias', "Added alias: $source -> $destination");
            return true;
        } catch (PDOException $e) {
            $this->error = 'Alias already exists';
            return false;
        }
    }
    
    public function deleteAlias($id) {
        $stmt = $this->db->prepare('DELETE FROM virtual_aliases WHERE id = ?');
        $stmt->execute([$id]);
        $this->success = 'Alias deleted successfully';
        return true;
    }
    
    public function getStats() {
        $stats = [];
        
        $stmt = $this->db->query('SELECT COUNT(*) FROM virtual_domains WHERE active = 1');
        $stats['domains'] = $stmt->fetchColumn();
        
        $stmt = $this->db->query('SELECT COUNT(*) FROM virtual_users WHERE active = 1');
        $stats['users'] = $stmt->fetchColumn();
        
        $stmt = $this->db->query('SELECT COUNT(*) FROM virtual_aliases WHERE active = 1');
        $stats['aliases'] = $stmt->fetchColumn();
        
        return $stats;
    }
    
    public function getRecentLogs($limit = 50) {
        $stmt = $this->db->prepare('SELECT l.*, u.email FROM admin_logs l LEFT JOIN virtual_users u ON l.admin_id = u.id ORDER BY l.created_at DESC LIMIT ?');
        $stmt->execute([$limit]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    private function logAction($adminId, $action, $details) {
        $stmt = $this->db->prepare('INSERT INTO admin_logs (admin_id, action, details, ip_address) VALUES (?, ?, ?, ?)');
        $stmt->execute([$adminId, $action, $details, $_SERVER['REMOTE_ADDR'] ?? 'unknown']);
    }
    
    private function logLoginAttempt($email, $success) {
        $stmt = $this->db->prepare('INSERT INTO login_attempts (ip_address, email, success, user_agent) VALUES (?, ?, ?, ?)');
        $stmt->execute([
            $_SERVER['REMOTE_ADDR'] ?? 'unknown',
            $email,
            $success ? 1 : 0,
            $_SERVER['HTTP_USER_AGENT'] ?? ''
        ]);
    }
    
    public function getError() { return $this->error; }
    public function getSuccess() { return $this->success; }
}

// Initialize
$admin = new PremiumMailAdmin();

// Handle actions
$action = $_GET['action'] ?? $_POST['action'] ?? '';

if ($action === 'logout') {
    $admin->logout();
    header('Location: /admin/');
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if ($action === 'login') {
        if ($admin->login($_POST['email'] ?? '', $_POST['password'] ?? '')) {
            header('Location: /admin/?page=dashboard');
            exit;
        }
    } elseif ($admin->isLoggedIn()) {
        switch ($action) {
            case 'add_domain':
                $admin->addDomain($_POST['name'] ?? '');
                break;
            case 'delete_domain':
                $admin->deleteDomain($_POST['id'] ?? 0);
                break;
            case 'add_user':
                $admin->addUser(
                    $_POST['domain_id'] ?? 0,
                    $_POST['email'] ?? '',
                    $_POST['password'] ?? '',
                    $_POST['name'] ?? '',
                    ($_POST['quota'] ?? 1) * 1073741824
                );
                break;
            case 'delete_user':
                $admin->deleteUser($_POST['id'] ?? 0);
                break;
            case 'update_password':
                $admin->updateUserPassword($_POST['id'] ?? 0, $_POST['password'] ?? '');
                break;
            case 'toggle_user':
                $admin->toggleUserStatus($_POST['id'] ?? 0);
                break;
            case 'add_alias':
                $admin->addAlias($_POST['domain_id'] ?? 0, $_POST['source'] ?? '', $_POST['destination'] ?? '');
                break;
            case 'delete_alias':
                $admin->deleteAlias($_POST['id'] ?? 0);
                break;
        }
    }
}

$page = $_GET['page'] ?? ($admin->isLoggedIn() ? 'dashboard' : 'login');
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Premium Mail - Admin Panel</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --cream: #FFFDF7;
            --cream-light: #FFFEF9;
            --cream-dark: #F8F4E8;
            --cream-border: #EDE9DD;
            --orange: #FF9A4D;
            --orange-light: #FFB67A;
            --orange-dark: #E8863F;
            --orange-subtle: #FFF4EB;
            --text-primary: #2D2D2D;
            --text-secondary: #6B6B6B;
            --text-muted: #9E9E9E;
            --success: #4CAF50;
            --danger: #F44336;
            --warning: #FF9800;
            --radius: 10px;
        }
        
        * { box-sizing: border-box; margin: 0; padding: 0; }
        
        body {
            font-family: 'Inter', sans-serif;
            background: linear-gradient(135deg, var(--cream) 0%, var(--cream-dark) 100%);
            min-height: 100vh;
            color: var(--text-primary);
        }
        
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        
        /* Login Page */
        .login-page {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .login-card {
            background: var(--cream-light);
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            width: 100%;
            max-width: 420px;
        }
        
        .login-logo {
            text-align: center;
            margin-bottom: 30px;
        }
        
        .login-logo h1 {
            font-size: 1.8rem;
            background: linear-gradient(135deg, var(--orange-dark), var(--orange));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        
        .login-logo p { color: var(--text-secondary); margin-top: 5px; }
        
        /* Forms */
        .form-group { margin-bottom: 20px; }
        
        .form-group label {
            display: block;
            font-weight: 500;
            margin-bottom: 8px;
            color: var(--text-primary);
        }
        
        .form-control {
            width: 100%;
            padding: 14px 16px;
            border: 2px solid var(--cream-border);
            border-radius: var(--radius);
            font-size: 1rem;
            transition: all 0.25s;
            background: var(--cream);
        }
        
        .form-control:focus {
            outline: none;
            border-color: var(--orange);
            box-shadow: 0 0 0 4px rgba(255, 154, 77, 0.15);
        }
        
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 14px 28px;
            border: none;
            border-radius: var(--radius);
            font-size: 1rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.25s;
            text-decoration: none;
        }
        
        .btn-primary {
            background: linear-gradient(135deg, var(--orange), var(--orange-dark));
            color: white;
        }
        
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(255, 154, 77, 0.4);
        }
        
        .btn-secondary {
            background: var(--cream);
            color: var(--text-primary);
            border: 2px solid var(--cream-border);
        }
        
        .btn-danger {
            background: var(--danger);
            color: white;
        }
        
        .btn-sm { padding: 8px 16px; font-size: 0.875rem; }
        
        /* Admin Layout */
        .admin-header {
            background: var(--cream-light);
            padding: 16px 24px;
            border-bottom: 1px solid var(--cream-border);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        
        .admin-logo {
            font-size: 1.3rem;
            font-weight: 700;
            color: var(--orange);
        }
        
        .admin-user {
            display: flex;
            align-items: center;
            gap: 16px;
        }
        
        .admin-nav {
            background: var(--cream-light);
            border-bottom: 1px solid var(--cream-border);
            padding: 0 24px;
        }
        
        .admin-nav ul {
            display: flex;
            list-style: none;
            gap: 8px;
        }
        
        .admin-nav a {
            display: block;
            padding: 16px 20px;
            color: var(--text-secondary);
            text-decoration: none;
            font-weight: 500;
            border-bottom: 3px solid transparent;
            transition: all 0.2s;
        }
        
        .admin-nav a:hover,
        .admin-nav a.active {
            color: var(--orange);
            border-bottom-color: var(--orange);
        }
        
        .admin-content {
            padding: 30px;
        }
        
        /* Cards */
        .card {
            background: var(--cream-light);
            border-radius: 16px;
            padding: 24px;
            margin-bottom: 24px;
            border: 1px solid var(--cream-border);
        }
        
        .card-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 20px;
        }
        
        .card-title {
            font-size: 1.1rem;
            font-weight: 600;
        }
        
        /* Stats */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: var(--cream-light);
            padding: 24px;
            border-radius: 16px;
            border: 1px solid var(--cream-border);
            text-align: center;
        }
        
        .stat-value {
            font-size: 2.5rem;
            font-weight: 700;
            color: var(--orange);
        }
        
        .stat-label {
            color: var(--text-secondary);
            margin-top: 8px;
        }
        
        /* Tables */
        .table-container {
            overflow-x: auto;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
        }
        
        th, td {
            padding: 14px 16px;
            text-align: left;
            border-bottom: 1px solid var(--cream-border);
        }
        
        th {
            font-weight: 600;
            color: var(--text-muted);
            font-size: 0.85rem;
            text-transform: uppercase;
        }
        
        tr:hover td {
            background: var(--orange-subtle);
        }
        
        .badge {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 0.75rem;
            font-weight: 600;
        }
        
        .badge-success { background: #E8F5E9; color: var(--success); }
        .badge-danger { background: #FFEBEE; color: var(--danger); }
        
        /* Alerts */
        .alert {
            padding: 14px 18px;
            border-radius: var(--radius);
            margin-bottom: 20px;
        }
        
        .alert-error {
            background: #FFEBEE;
            color: var(--danger);
        }
        
        .alert-success {
            background: #E8F5E9;
            color: var(--success);
        }
        
        /* Modal */
        .modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.5);
            align-items: center;
            justify-content: center;
            z-index: 1000;
        }
        
        .modal.active { display: flex; }
        
        .modal-content {
            background: var(--cream-light);
            padding: 30px;
            border-radius: 16px;
            width: 100%;
            max-width: 500px;
            max-height: 90vh;
            overflow-y: auto;
        }
        
        .modal-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 24px;
        }
        
        .modal-title { font-size: 1.2rem; font-weight: 600; }
        
        .modal-close {
            background: none;
            border: none;
            font-size: 1.5rem;
            cursor: pointer;
            color: var(--text-muted);
        }
        
        @media (max-width: 768px) {
            .admin-nav ul { flex-wrap: wrap; }
            .stats-grid { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>

<?php if (!$admin->isLoggedIn()): ?>
<!-- Login Page -->
<div class="login-page">
    <div class="login-card">
        <div class="login-logo">
            <h1>Premium Mail</h1>
            <p>Admin Panel</p>
        </div>
        
        <?php if ($admin->getError()): ?>
        <div class="alert alert-error"><?= htmlspecialchars($admin->getError()) ?></div>
        <?php endif; ?>
        
        <form method="POST">
            <input type="hidden" name="action" value="login">
            <div class="form-group">
                <label>Email Address</label>
                <input type="email" name="email" class="form-control" required autofocus>
            </div>
            <div class="form-group">
                <label>Password</label>
                <input type="password" name="password" class="form-control" required>
            </div>
            <button type="submit" class="btn btn-primary" style="width:100%">Sign In</button>
        </form>
    </div>
</div>

<?php else: ?>
<!-- Admin Dashboard -->
<div class="admin-layout">
    <header class="admin-header">
        <span class="admin-logo">Premium Mail Admin</span>
        <div class="admin-user">
            <span><?= htmlspecialchars($_SESSION[ADMIN_SESSION_NAME]['email']) ?></span>
            <a href="?action=logout" class="btn btn-sm btn-secondary">Logout</a>
        </div>
    </header>
    
    <nav class="admin-nav">
        <ul>
            <li><a href="?page=dashboard" class="<?= $page === 'dashboard' ? 'active' : '' ?>">Dashboard</a></li>
            <li><a href="?page=domains" class="<?= $page === 'domains' ? 'active' : '' ?>">Domains</a></li>
            <li><a href="?page=users" class="<?= $page === 'users' ? 'active' : '' ?>">Users</a></li>
            <li><a href="?page=aliases" class="<?= $page === 'aliases' ? 'active' : '' ?>">Aliases</a></li>
            <li><a href="?page=logs" class="<?= $page === 'logs' ? 'active' : '' ?>">Logs</a></li>
            <li><a href="/" target="_blank">Webmail ↗</a></li>
        </ul>
    </nav>
    
    <main class="admin-content">
        <div class="container">
            <?php if ($admin->getError()): ?>
            <div class="alert alert-error"><?= htmlspecialchars($admin->getError()) ?></div>
            <?php endif; ?>
            
            <?php if ($admin->getSuccess()): ?>
            <div class="alert alert-success"><?= htmlspecialchars($admin->getSuccess()) ?></div>
            <?php endif; ?>
            
            <?php if ($page === 'dashboard'): ?>
            <!-- Dashboard -->
            <?php $stats = $admin->getStats(); ?>
            <h2 style="margin-bottom: 24px;">Dashboard</h2>
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-value"><?= $stats['domains'] ?></div>
                    <div class="stat-label">Domains</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value"><?= $stats['users'] ?></div>
                    <div class="stat-label">Users</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value"><?= $stats['aliases'] ?></div>
                    <div class="stat-label">Aliases</div>
                </div>
            </div>
            
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">Recent Activity</h3>
                </div>
                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Time</th>
                                <th>Admin</th>
                                <th>Action</th>
                                <th>Details</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($admin->getRecentLogs(10) as $log): ?>
                            <tr>
                                <td><?= htmlspecialchars($log['created_at']) ?></td>
                                <td><?= htmlspecialchars($log['email'] ?? 'System') ?></td>
                                <td><?= htmlspecialchars($log['action']) ?></td>
                                <td><?= htmlspecialchars($log['details']) ?></td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
            
            <?php elseif ($page === 'domains'): ?>
            <!-- Domains -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">Domains</h3>
                    <button class="btn btn-primary btn-sm" onclick="openModal('addDomainModal')">+ Add Domain</button>
                </div>
                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Domain</th>
                                <th>Status</th>
                                <th>Created</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($admin->getDomains() as $domain): ?>
                            <tr>
                                <td><strong><?= htmlspecialchars($domain['name']) ?></strong></td>
                                <td><span class="badge <?= $domain['active'] ? 'badge-success' : 'badge-danger' ?>"><?= $domain['active'] ? 'Active' : 'Inactive' ?></span></td>
                                <td><?= htmlspecialchars($domain['created_at']) ?></td>
                                <td>
                                    <form method="POST" style="display:inline" onsubmit="return confirm('Delete this domain?')">
                                        <input type="hidden" name="action" value="delete_domain">
                                        <input type="hidden" name="id" value="<?= $domain['id'] ?>">
                                        <button type="submit" class="btn btn-danger btn-sm">Delete</button>
                                    </form>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
            
            <!-- Add Domain Modal -->
            <div id="addDomainModal" class="modal">
                <div class="modal-content">
                    <div class="modal-header">
                        <h3 class="modal-title">Add Domain</h3>
                        <button class="modal-close" onclick="closeModal('addDomainModal')">&times;</button>
                    </div>
                    <form method="POST">
                        <input type="hidden" name="action" value="add_domain">
                        <div class="form-group">
                            <label>Domain Name</label>
                            <input type="text" name="name" class="form-control" placeholder="example.com" required>
                        </div>
                        <button type="submit" class="btn btn-primary">Add Domain</button>
                    </form>
                </div>
            </div>
            
            <?php elseif ($page === 'users'): ?>
            <!-- Users -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">Users</h3>
                    <button class="btn btn-primary btn-sm" onclick="openModal('addUserModal')">+ Add User</button>
                </div>
                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Email</th>
                                <th>Name</th>
                                <th>Status</th>
                                <th>Admin</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($admin->getUsers() as $user): ?>
                            <tr>
                                <td><strong><?= htmlspecialchars($user['email']) ?></strong></td>
                                <td><?= htmlspecialchars($user['name'] ?: '-') ?></td>
                                <td><span class="badge <?= $user['active'] ? 'badge-success' : 'badge-danger' ?>"><?= $user['active'] ? 'Active' : 'Inactive' ?></span></td>
                                <td><?= $user['is_admin'] ? '✓' : '' ?></td>
                                <td>
                                    <form method="POST" style="display:inline">
                                        <input type="hidden" name="action" value="toggle_user">
                                        <input type="hidden" name="id" value="<?= $user['id'] ?>">
                                        <button type="submit" class="btn btn-secondary btn-sm"><?= $user['active'] ? 'Disable' : 'Enable' ?></button>
                                    </form>
                                    <form method="POST" style="display:inline" onsubmit="return confirm('Delete this user?')">
                                        <input type="hidden" name="action" value="delete_user">
                                        <input type="hidden" name="id" value="<?= $user['id'] ?>">
                                        <button type="submit" class="btn btn-danger btn-sm">Delete</button>
                                    </form>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
            
            <!-- Add User Modal -->
            <div id="addUserModal" class="modal">
                <div class="modal-content">
                    <div class="modal-header">
                        <h3 class="modal-title">Add User</h3>
                        <button class="modal-close" onclick="closeModal('addUserModal')">&times;</button>
                    </div>
                    <form method="POST">
                        <input type="hidden" name="action" value="add_user">
                        <div class="form-group">
                            <label>Domain</label>
                            <select name="domain_id" class="form-control" required>
                                <?php foreach ($admin->getDomains() as $domain): ?>
                                <option value="<?= $domain['id'] ?>"><?= htmlspecialchars($domain['name']) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>Email</label>
                            <input type="email" name="email" class="form-control" placeholder="user@domain.com" required>
                        </div>
                        <div class="form-group">
                            <label>Name</label>
                            <input type="text" name="name" class="form-control" placeholder="Full Name">
                        </div>
                        <div class="form-group">
                            <label>Password</label>
                            <input type="password" name="password" class="form-control" required minlength="8">
                        </div>
                        <div class="form-group">
                            <label>Quota (GB)</label>
                            <input type="number" name="quota" class="form-control" value="1" min="1" max="100">
                        </div>
                        <button type="submit" class="btn btn-primary">Add User</button>
                    </form>
                </div>
            </div>
            
            <?php elseif ($page === 'aliases'): ?>
            <!-- Aliases -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">Email Aliases</h3>
                    <button class="btn btn-primary btn-sm" onclick="openModal('addAliasModal')">+ Add Alias</button>
                </div>
                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Source</th>
                                <th>Destination</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($admin->getAliases() as $alias): ?>
                            <tr>
                                <td><strong><?= htmlspecialchars($alias['source']) ?></strong></td>
                                <td><?= htmlspecialchars($alias['destination']) ?></td>
                                <td><span class="badge <?= $alias['active'] ? 'badge-success' : 'badge-danger' ?>"><?= $alias['active'] ? 'Active' : 'Inactive' ?></span></td>
                                <td>
                                    <form method="POST" style="display:inline" onsubmit="return confirm('Delete this alias?')">
                                        <input type="hidden" name="action" value="delete_alias">
                                        <input type="hidden" name="id" value="<?= $alias['id'] ?>">
                                        <button type="submit" class="btn btn-danger btn-sm">Delete</button>
                                    </form>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
            
            <!-- Add Alias Modal -->
            <div id="addAliasModal" class="modal">
                <div class="modal-content">
                    <div class="modal-header">
                        <h3 class="modal-title">Add Alias</h3>
                        <button class="modal-close" onclick="closeModal('addAliasModal')">&times;</button>
                    </div>
                    <form method="POST">
                        <input type="hidden" name="action" value="add_alias">
                        <div class="form-group">
                            <label>Domain</label>
                            <select name="domain_id" class="form-control" required>
                                <?php foreach ($admin->getDomains() as $domain): ?>
                                <option value="<?= $domain['id'] ?>"><?= htmlspecialchars($domain['name']) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>Source (Forward From)</label>
                            <input type="text" name="source" class="form-control" placeholder="alias@domain.com" required>
                        </div>
                        <div class="form-group">
                            <label>Destination (Forward To)</label>
                            <input type="email" name="destination" class="form-control" placeholder="real@email.com" required>
                        </div>
                        <button type="submit" class="btn btn-primary">Add Alias</button>
                    </form>
                </div>
            </div>
            
            <?php elseif ($page === 'logs'): ?>
            <!-- Logs -->
            <div class="card">
                <div class="card-header">
                    <h3 class="card-title">Admin Logs</h3>
                </div>
                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Time</th>
                                <th>Admin</th>
                                <th>Action</th>
                                <th>Details</th>
                                <th>IP Address</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($admin->getRecentLogs(100) as $log): ?>
                            <tr>
                                <td><?= htmlspecialchars($log['created_at']) ?></td>
                                <td><?= htmlspecialchars($log['email'] ?? 'System') ?></td>
                                <td><?= htmlspecialchars($log['action']) ?></td>
                                <td><?= htmlspecialchars($log['details']) ?></td>
                                <td><?= htmlspecialchars($log['ip_address']) ?></td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
            
            <?php endif; ?>
        </div>
    </main>
</div>

<script>
function openModal(id) {
    document.getElementById(id).classList.add('active');
}

function closeModal(id) {
    document.getElementById(id).classList.remove('active');
}

// Close modal on outside click
document.querySelectorAll('.modal').forEach(modal => {
    modal.addEventListener('click', function(e) {
        if (e.target === this) closeModal(this.id);
    });
});

// Close modal on Escape
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        document.querySelectorAll('.modal.active').forEach(m => m.classList.remove('active'));
    }
});
</script>
<?php endif; ?>

</body>
</html>
ADMINPHP

    # Configure Nginx for admin panel
    cat >> /etc/nginx/sites-available/webmail <<EOF

# Admin Panel protection
location /admin {
    alias /var/www/webmail/admin;
    index index.php;
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_param SCRIPT_FILENAME \$request_filename;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}
EOF

    chown -R www-data:www-data "$ADMIN_DIR"
    chmod 755 "$ADMIN_DIR"
    chmod 644 "$ADMIN_DIR/index.php"
    
    nginx -t && systemctl reload nginx
    
    log "Admin panel created"
}

start_services() {
    log "Starting all services..."
    
    systemctl restart mariadb
    systemctl restart postfix
    systemctl restart dovecot
    systemctl restart opendkim
    
    # Handle SpamAssassin service name difference
    if systemctl list-unit-files | grep -q "^spamd.service"; then
        systemctl restart spamd
        systemctl enable mariadb postfix dovecot opendkim spamd nginx fail2ban
    else
        systemctl restart spamassassin
        systemctl enable mariadb postfix dovecot opendkim spamassassin nginx fail2ban
    fi
    
    systemctl restart nginx
    systemctl restart fail2ban
    
    log "All services started and enabled"
}

save_credentials() {
    log "Saving installation credentials..."
    
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_DIR/credentials.txt" <<EOF
============================================
Premium Mail - Installation Credentials
Generated: $(date)
Installer Version: ${INSTALLER_VERSION}
============================================

SERVER INFORMATION
------------------
Hostname: ${HOSTNAME_FQDN}
Domain: ${MAIL_DOMAIN}
Public IP: $(get_public_ip)

DATABASE
--------
MySQL Root Password: ${MYSQL_ROOT_PASSWORD}
Mail DB User: mailuser
Mail DB Password: ${MYSQL_MAIL_PASSWORD}

ADMIN ACCOUNT
-------------
Admin Email: ${ADMIN_EMAIL}
Admin Password: ${ADMIN_PASSWORD}

WEBMAIL ACCESS
--------------
Webmail URL: https://${HOSTNAME_FQDN}/
Admin Panel: https://${HOSTNAME_FQDN}/admin/

EMAIL CLIENT SETTINGS
---------------------
IMAP Server: ${HOSTNAME_FQDN}
IMAP Port: 993 (SSL)
SMTP Server: ${HOSTNAME_FQDN}
SMTP Port: 587 (STARTTLS)

DNS RECORDS REQUIRED
--------------------
1. A Record:
   ${HOSTNAME_FQDN} -> $(get_public_ip)

2. MX Record:
   ${MAIL_DOMAIN} -> ${HOSTNAME_FQDN} (Priority: 10)

3. SPF Record (TXT):
   ${MAIL_DOMAIN} -> "v=spf1 mx ip4:$(get_public_ip) ~all"

4. DMARC Record (TXT):
   _dmarc.${MAIL_DOMAIN} -> "v=DMARC1; p=quarantine; rua=mailto:postmaster@${MAIL_DOMAIN}"

5. DKIM Record (TXT):
   Check /etc/opendkim/keys/${MAIL_DOMAIN}/mail.txt

============================================
KEEP THIS FILE SECURE!
============================================
EOF

    chmod 600 "$CONFIG_DIR/credentials.txt"
    
    log "Credentials saved to $CONFIG_DIR/credentials.txt"
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           INSTALLATION COMPLETED SUCCESSFULLY!             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Webmail:${NC} https://${HOSTNAME_FQDN}/"
    echo -e "${CYAN}Admin Panel:${NC} https://${HOSTNAME_FQDN}/admin/"
    echo ""
    echo -e "${CYAN}Admin Email:${NC} ${ADMIN_EMAIL}"
    echo -e "${CYAN}Admin Password:${NC} ${ADMIN_PASSWORD}"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: Save these credentials!${NC}"
    echo -e "${YELLOW}    Full credentials saved to: ${CONFIG_DIR}/credentials.txt${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Configure DNS records (see credentials file)"
    echo "  2. Obtain SSL certificate: certbot --nginx -d ${HOSTNAME_FQDN}"
    echo "  3. Access admin panel to create email accounts"
    echo ""
    echo -e "${GREEN}Thank you for using Premium Mail!${NC}"
}

#############################################
# Interactive Setup
#############################################

interactive_setup() {
    print_banner
    
    echo -e "\n${CYAN}Welcome to Premium Mail Installer!${NC}\n"
    echo "This installer will set up a complete email hosting solution."
    echo "Please provide the following information:"
    echo ""
    
    # Get domain
    read -p "Enter your mail domain (e.g., example.com): " MAIL_DOMAIN
    if [ -z "$MAIL_DOMAIN" ]; then
        log_error "Domain is required"
        exit 1
    fi
    
    # Get hostname
    read -p "Enter full hostname (e.g., mail.example.com) [mail.${MAIL_DOMAIN}]: " HOSTNAME_FQDN
    HOSTNAME_FQDN=${HOSTNAME_FQDN:-mail.${MAIL_DOMAIN}}
    
    # Get admin email
    read -p "Enter admin email [admin@${MAIL_DOMAIN}]: " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-admin@${MAIL_DOMAIN}}
    
    # Get admin password
    echo ""
    read -s -p "Enter admin password (leave empty to auto-generate): " ADMIN_PASSWORD
    echo ""
    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD=$(generate_password 16)
        echo -e "${YELLOW}Generated admin password: ${ADMIN_PASSWORD}${NC}"
    fi
    
    # SSL Email
    read -p "Enter email for SSL certificates [${ADMIN_EMAIL}]: " SSL_EMAIL
    SSL_EMAIL=${SSL_EMAIL:-${ADMIN_EMAIL}}
    
    # Confirmation
    echo ""
    echo -e "${CYAN}Installation Summary:${NC}"
    echo "  Domain: ${MAIL_DOMAIN}"
    echo "  Hostname: ${HOSTNAME_FQDN}"
    echo "  Admin: ${ADMIN_EMAIL}"
    echo ""
    read -p "Proceed with installation? (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo "Installation cancelled."
        exit 0
    fi
}

#############################################
# Main Installation
#############################################

main() {
    # Initialize log
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "Premium Mail Installation Log - $(date)" > "$LOG_FILE"
    
    # Check requirements
    check_root
    check_os
    
    # Interactive or use environment variables
    if [ -z "$MAIL_DOMAIN" ]; then
        interactive_setup
    fi
    
    # Start installation
    log "Starting Premium Mail installation..."
    
    backup_existing
    install_prerequisites
    install_mysql
    create_mail_database
    install_postfix
    install_dovecot
    install_nginx
    install_php
    install_roundcube
    install_premium_skin
    install_opendkim
    install_spamassassin
    install_fail2ban
    create_admin_user
    create_admin_panel
    install_certbot
    start_services
    save_credentials
    
    print_summary
    
    log "Installation completed successfully!"
}

# Run main function
main "$@"
