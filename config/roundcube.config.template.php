<?php
/**
 * Premium Mail - Roundcube Configuration Template
 * 
 * This is a configuration template. The installer will generate
 * the actual config with your specific values.
 * 
 * For manual installation, copy this to:
 * /var/www/webmail/config/config.inc.php
 */

// Database connection
$config['db_dsnw'] = 'mysql://mailuser:PASSWORD@127.0.0.1/roundcube';

// IMAP Server - Use ssl:// for port 993
$config['default_host'] = 'ssl://localhost';
$config['default_port'] = 993;
$config['imap_auth_type'] = 'PLAIN';
$config['imap_conn_options'] = array(
    'ssl' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
    ),
);

// SMTP Server - Use tls:// for port 587
$config['smtp_server'] = 'tls://localhost';
$config['smtp_port'] = 587;
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';
$config['smtp_auth_type'] = 'PLAIN';
$config['smtp_conn_options'] = array(
    'ssl' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
    ),
);

// System settings
$config['support_url'] = '';
$config['product_name'] = 'Premium Mail';
$config['des_key'] = 'REPLACE_WITH_24_CHAR_KEY!!';

// Enabled plugins
$config['plugins'] = array(
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
$config['language'] = 'en_US';
$config['skin'] = 'premium_starter';
$config['skin_logo'] = null;
$config['timezone'] = 'auto';
$config['date_format'] = 'Y-m-d';
$config['time_format'] = 'H:i';
$config['refresh_interval'] = 60;
$config['message_show_email'] = true;
$config['prefer_html'] = true;
$config['htmleditor'] = 4;
$config['draft_autosave'] = 60;
$config['mime_param_folding'] = 0;
$config['mdn_requests'] = 0;

// Addressbook settings
$config['autocomplete_addressbooks'] = array('sql');
$config['autocomplete_min_length'] = 1;
$config['autocomplete_max'] = 15;
$config['address_book_type'] = 'sql';

// Caching
$config['imap_cache'] = 'db';
$config['imap_cache_ttl'] = '10d';
$config['messages_cache'] = 'db';
$config['messages_cache_ttl'] = '10d';
$config['session_lifetime'] = 30;

// Attachments
$config['max_message_size'] = '50M';
$config['max_group_members'] = 50;

// Security settings
$config['login_autocomplete'] = 2;
$config['ip_check'] = true;
$config['x_frame_options'] = 'sameorigin';
$config['use_https'] = true;
$config['password_charset'] = 'UTF-8';

// Sieve (Mail Filters)
$config['managesieve_host'] = 'localhost';
$config['managesieve_port'] = 4190;
$config['managesieve_auth_type'] = 'PLAIN';
$config['managesieve_usetls'] = true;

// Password plugin - for changing passwords
$config['password_driver'] = 'sql';
$config['password_db_dsn'] = 'mysql://mailuser:PASSWORD@127.0.0.1/mailserver';
$config['password_query'] = 'UPDATE virtual_users SET password=%P WHERE email=%u';
$config['password_crypt_hash'] = 'sha512';
$config['password_algorithm'] = 'crypt';
$config['password_minimum_length'] = 8;
$config['password_require_nonalpha'] = true;
$config['password_force_new_user'] = false;

// Logging
$config['log_driver'] = 'file';
$config['log_dir'] = '/var/log/roundcube/';
$config['per_user_logging'] = false;

// Debugging (set to true for troubleshooting)
$config['debug_level'] = 0;
$config['sql_debug'] = false;
$config['imap_debug'] = false;
$config['smtp_debug'] = false;

/**
 * Additional Configuration Options
 * 
 * See: https://github.com/roundcube/roundcubemail/wiki/Configuration
 * for complete list of configuration options.
 */
