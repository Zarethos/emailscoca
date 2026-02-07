#!/bin/bash

#############################################
# Premium Mail - Uninstaller
# This script removes Premium Mail installation
#############################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║            PREMIUM MAIL UNINSTALLER                         ║"
echo "║                                                              ║"
echo "║  ⚠️  WARNING: This will remove all mail data!               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}This will remove:${NC}"
echo "  - Postfix mail server"
echo "  - Dovecot IMAP/POP3 server"
echo "  - Roundcube webmail"
echo "  - All email data and databases"
echo "  - Nginx configuration"
echo "  - SSL certificates"
echo ""

read -p "Are you ABSOLUTELY sure? Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""
read -p "Do you want to backup data before removal? (y/n): " backup

if [[ "$backup" =~ ^[Yy] ]]; then
    BACKUP_DIR="/root/premium-mail-final-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    echo "Creating backup..."
    
    # Backup databases
    mysqldump --all-databases > "$BACKUP_DIR/all-databases.sql" 2>/dev/null || true
    
    # Backup mail
    [ -d "/var/mail/vhosts" ] && cp -r /var/mail/vhosts "$BACKUP_DIR/"
    
    # Backup configs
    [ -d "/etc/postfix" ] && cp -r /etc/postfix "$BACKUP_DIR/"
    [ -d "/etc/dovecot" ] && cp -r /etc/dovecot "$BACKUP_DIR/"
    [ -d "/etc/nginx" ] && cp -r /etc/nginx "$BACKUP_DIR/"
    [ -f "/etc/premium-mail/credentials.txt" ] && cp /etc/premium-mail/credentials.txt "$BACKUP_DIR/"
    
    echo -e "${GREEN}Backup saved to: $BACKUP_DIR${NC}"
fi

echo ""
echo "Stopping services..."

systemctl stop postfix dovecot nginx opendkim spamassassin fail2ban 2>/dev/null || true
systemctl disable postfix dovecot nginx opendkim spamassassin fail2ban 2>/dev/null || true

echo "Removing packages..."

apt-get purge -y \
    postfix postfix-mysql \
    dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-mysql dovecot-sieve dovecot-managesieved \
    opendkim opendkim-tools \
    spamassassin spamc \
    roundcube* \
    2>/dev/null || true

apt-get autoremove -y

echo "Removing files..."

rm -rf /var/mail/vhosts
rm -rf /var/www/webmail
rm -rf /etc/postfix
rm -rf /etc/dovecot
rm -rf /etc/opendkim
rm -rf /etc/premium-mail
rm -rf /var/log/roundcube
rm -f /etc/nginx/sites-enabled/webmail
rm -f /etc/nginx/sites-available/webmail

echo "Cleaning up databases..."

if command -v mysql &> /dev/null; then
    read -p "Enter MySQL root password to drop databases (or press Enter to skip): " -s mysql_pass
    echo ""
    
    if [ -n "$mysql_pass" ]; then
        mysql -u root -p"$mysql_pass" -e "DROP DATABASE IF EXISTS mailserver; DROP DATABASE IF EXISTS roundcube; DROP USER IF EXISTS 'mailuser'@'localhost';" 2>/dev/null || true
        echo "Databases removed."
    fi
fi

echo "Removing vmail user..."
userdel vmail 2>/dev/null || true
groupdel vmail 2>/dev/null || true

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           UNINSTALLATION COMPLETED                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"

if [[ "$backup" =~ ^[Yy] ]]; then
    echo ""
    echo -e "${YELLOW}Your backup is saved at: $BACKUP_DIR${NC}"
fi

echo ""
echo "Note: MariaDB and Nginx are still installed. Remove manually if needed:"
echo "  apt-get purge mariadb-server nginx"
