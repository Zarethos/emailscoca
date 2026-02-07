# Premium Mail

A complete email hosting solution with a beautiful premium Roundcube skin and automated VPS installer.

![Premium Mail](https://img.shields.io/badge/Version-2.0.0-orange)
![License](https://img.shields.io/badge/License-MIT-blue)
![Roundcube](https://img.shields.io/badge/Roundcube-1.6.6-green)

## Features

### Premium Starter Skin
- 🎨 Beautiful creamy white and light orange color scheme
- 🌙 Dark mode support
- 📱 Fully responsive design
- ⚡ Smooth animations and transitions
- ⌨️ Keyboard shortcuts
- 🔔 Desktop notifications
- 📎 Drag and drop attachments
- 🔍 Enhanced search

### Email Server
- 📧 Postfix SMTP server with TLS
- 📥 Dovecot IMAP/POP3 with quotas
- 🔐 DKIM, SPF, DMARC support
- 🛡️ SpamAssassin anti-spam
- 🔒 Fail2Ban protection
- 📜 Sieve mail filtering
- 🔑 Let's Encrypt SSL

### Admin Panel
- 👥 User management
- 🌐 Domain management
- 📨 Email alias support
- 📊 Statistics dashboard
- 📝 Activity logs
- 🔐 Secure authentication

## Requirements

- Ubuntu 20.04/22.04/24.04 or Debian 11/12
- Minimum 1GB RAM (2GB recommended)
- 20GB disk space
- Root access
- Domain with DNS control
- Clean VPS (fresh installation recommended)

## Quick Install

### One-Command Installation

```bash
wget -O install.sh https://raw.githubusercontent.com/your-repo/premium-mail/main/installer/install.sh && chmod +x install.sh && sudo ./install.sh
```

### Manual Installation

1. Download the installer:
```bash
git clone https://github.com/your-repo/premium-mail.git
cd premium-mail/installer
chmod +x install.sh
```

2. Run the installer:
```bash
sudo ./install.sh
```

3. Follow the interactive prompts.

### Automated Installation

For non-interactive installation:

```bash
# Copy and edit configuration
cp config.env.example config.env
nano config.env

# Source config and run
source config.env
sudo -E ./install.sh
```

## Post-Installation

### 1. Configure DNS Records

See [DNS-GUIDE.md](installer/DNS-GUIDE.md) for detailed DNS configuration.

Required records:
- **A Record**: `mail.yourdomain.com` → Server IP
- **MX Record**: `yourdomain.com` → `mail.yourdomain.com`
- **SPF Record**: TXT record for sender verification
- **DKIM Record**: TXT record for email signing
- **DMARC Record**: TXT record for policy

### 2. Obtain SSL Certificate

```bash
sudo certbot --nginx -d mail.yourdomain.com
```

### 3. Access Webmail

- **Webmail**: https://mail.yourdomain.com/
- **Admin Panel**: https://mail.yourdomain.com/admin/

### 4. Create Email Accounts

1. Login to admin panel with your admin credentials
2. Go to "Users" section
3. Click "Add User"
4. Fill in email, password, and quota

## Email Client Configuration

### IMAP Settings
- **Server**: mail.yourdomain.com
- **Port**: 993
- **Security**: SSL/TLS
- **Username**: Full email address
- **Password**: Your email password

### SMTP Settings
- **Server**: mail.yourdomain.com
- **Port**: 587
- **Security**: STARTTLS
- **Authentication**: Required
- **Username**: Full email address
- **Password**: Your email password

## Directory Structure

```
premium-mail/
├── installer/
│   ├── install.sh          # Main installer script
│   ├── uninstall.sh         # Uninstaller script
│   ├── config.env.example   # Configuration template
│   └── DNS-GUIDE.md         # DNS configuration guide
├── roundcube-skin/
│   └── premium_starter/
│       ├── meta.json        # Skin metadata
│       ├── styles.css       # Main stylesheet
│       ├── premium.js       # JavaScript enhancements
│       ├── images/          # Skin images
│       └── templates/       # HTML templates
├── config/                  # Configuration templates
└── README.md               # This file
```

## Customization

### Changing Colors

Edit `roundcube-skin/premium_starter/styles.css` and modify the CSS variables:

```css
:root {
    --cream: #FFFDF7;
    --orange: #FF9A4D;
    /* ... other variables */
}
```

### Adding Logo

1. Place your logo in `roundcube-skin/premium_starter/images/`
2. Update `meta.json` with logo path
3. Modify `templates/login.html` if needed

### Custom Templates

Templates are in `roundcube-skin/premium_starter/templates/`:
- `login.html` - Login page
- `mail.html` - Main mail interface
- `compose.html` - Email composition

## Troubleshooting

### Cannot Receive Emails

1. Check MX record: `dig MX yourdomain.com`
2. Verify Postfix is running: `systemctl status postfix`
3. Check firewall: `ufw status`
4. Review logs: `tail -f /var/log/mail.log`

### Cannot Send Emails

1. Check SMTP authentication
2. Verify port 587 is open
3. Check SPF/DKIM records
4. Review Postfix logs

### SSL Certificate Issues

1. Verify A record is correct
2. Wait for DNS propagation
3. Run: `sudo certbot --nginx -d mail.yourdomain.com`

### Webmail Not Loading

1. Check Nginx: `systemctl status nginx`
2. Check PHP-FPM: `systemctl status php*-fpm`
3. Review Nginx logs: `tail -f /var/log/nginx/error.log`

### Admin Login Issues

1. Verify admin user exists in database
2. Reset password via command line:
```bash
doveadm pw -s SHA512-CRYPT -p "newpassword"
# Then update in database
```

## Security Recommendations

1. **Regular Updates**: Keep system packages updated
```bash
apt update && apt upgrade -y
```

2. **Firewall**: Only allow necessary ports
```bash
ufw allow 22,25,80,443,587,993,995/tcp
ufw enable
```

3. **Strong Passwords**: Use generated passwords for all accounts

4. **Monitoring**: Check logs regularly
```bash
tail -f /var/log/mail.log
tail -f /var/log/fail2ban.log
```

5. **Backups**: Regular backup of mail data
```bash
tar -czf mail-backup.tar.gz /var/mail/vhosts /etc/postfix /etc/dovecot
```

## Maintenance

### Restart Services
```bash
systemctl restart postfix dovecot nginx
```

### Clear Mail Queue
```bash
postsuper -d ALL
```

### Check Mail Queue
```bash
mailq
```

### Update Roundcube
```bash
# Download new version
wget https://github.com/roundcube/roundcubemail/releases/download/X.X.X/roundcubemail-X.X.X-complete.tar.gz
# Backup current installation
cp -r /var/www/webmail /var/www/webmail-backup
# Update (follow official Roundcube upgrade guide)
```

## Uninstallation

To completely remove Premium Mail:

```bash
cd installer
sudo ./uninstall.sh
```

This will:
- Stop all mail services
- Remove mail packages
- Delete mail data (with backup option)
- Clean up configurations

## Support

- 📚 Documentation: [GitHub Wiki](https://github.com/your-repo/premium-mail/wiki)
- 🐛 Issues: [GitHub Issues](https://github.com/your-repo/premium-mail/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/your-repo/premium-mail/discussions)

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Roundcube](https://roundcube.net/) - The webmail platform
- [Postfix](http://www.postfix.org/) - Mail Transfer Agent
- [Dovecot](https://www.dovecot.org/) - IMAP/POP3 server
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates

---

**Premium Mail** - Professional email hosting made simple. 🚀
