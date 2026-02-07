# Premium Mail - DNS Configuration Guide

This guide explains how to configure DNS records for your email server.

## Required DNS Records

Replace `example.com` with your actual domain and `123.123.123.123` with your server's IP address.

### 1. A Record (Mail Server)

Points your mail hostname to your server IP.

```
Type: A
Name: mail
Value: 123.123.123.123
TTL: 3600
```

### 2. MX Record (Mail Exchange)

Tells other mail servers where to deliver mail for your domain.

```
Type: MX
Name: @ (or example.com)
Value: mail.example.com
Priority: 10
TTL: 3600
```

### 3. SPF Record (Sender Policy Framework)

Helps prevent email spoofing by specifying authorized mail servers.

```
Type: TXT
Name: @ (or example.com)
Value: "v=spf1 mx ip4:123.123.123.123 ~all"
TTL: 3600
```

**SPF Options:**
- `~all` - Soft fail (recommended for testing)
- `-all` - Hard fail (stricter, use after testing)

### 4. DKIM Record

Adds cryptographic signature to outgoing emails.

After installation, find your DKIM key at:
```
/etc/opendkim/keys/example.com/mail.txt
```

Create TXT record:
```
Type: TXT
Name: mail._domainkey
Value: (contents from mail.txt file)
TTL: 3600
```

Example value format:
```
v=DKIM1; k=rsa; p=MIIBIjANBgkqh...
```

### 5. DMARC Record

Policy for handling emails that fail SPF/DKIM checks.

```
Type: TXT
Name: _dmarc
Value: "v=DMARC1; p=quarantine; rua=mailto:postmaster@example.com; ruf=mailto:postmaster@example.com"
TTL: 3600
```

**DMARC Policy Options:**
- `p=none` - Monitor only (good for testing)
- `p=quarantine` - Send to spam folder
- `p=reject` - Reject completely

### 6. PTR Record (Reverse DNS)

Configure with your hosting provider. Points IP back to hostname.

```
IP: 123.123.123.123
Value: mail.example.com
```

> **Note:** PTR records must be configured by your VPS/hosting provider, not in your domain's DNS.

## Optional Records

### Autoconfig (Thunderbird)

```
Type: A
Name: autoconfig
Value: 123.123.123.123

Type: CNAME
Name: autoconfig
Value: mail.example.com
```

### Autodiscover (Outlook)

```
Type: CNAME
Name: autodiscover
Value: mail.example.com
```

### SRV Records (Service Discovery)

For email client auto-configuration:

```
# IMAP
Type: SRV
Name: _imaps._tcp
Value: 0 1 993 mail.example.com

# Submission
Type: SRV
Name: _submission._tcp
Value: 0 1 587 mail.example.com
```

## Verification Tools

After setting up DNS records, verify them:

### Check MX Record
```bash
dig MX example.com
```

### Check SPF Record
```bash
dig TXT example.com
```

### Check DKIM Record
```bash
dig TXT mail._domainkey.example.com
```

### Check DMARC Record
```bash
dig TXT _dmarc.example.com
```

### Online Tools
- [MXToolbox](https://mxtoolbox.com/)
- [Mail-Tester](https://www.mail-tester.com/)
- [DKIM Validator](https://dkimvalidator.com/)

## Common Issues

### Emails Going to Spam

1. Ensure PTR record is configured
2. Wait 24-48 hours for DNS propagation
3. Test with mail-tester.com
4. Check DKIM signature is valid

### Emails Not Receiving

1. Verify MX record points to correct hostname
2. Check A record for mail hostname
3. Verify firewall allows ports 25, 587, 465

### SSL Certificate Issues

1. Ensure A record is properly set before running certbot
2. Wait for DNS propagation (check with `dig A mail.example.com`)

## DNS Propagation

DNS changes can take up to 48 hours to propagate globally, though most changes take effect within a few hours.

Check propagation status:
- [DNS Checker](https://dnschecker.org/)
- [WhatsMyDNS](https://whatsmydns.net/)

## Security Best Practices

1. Start with `p=none` in DMARC, upgrade to `p=quarantine` after testing
2. Use `~all` in SPF initially, change to `-all` after verification
3. Regularly rotate DKIM keys (yearly recommended)
4. Monitor DMARC reports for unauthorized use

---

For more help, visit the Premium Mail documentation or open an issue on GitHub.
