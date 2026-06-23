# Email Notification Setup

The `/send-notification-email` skill requires `msmtp` — a lightweight SMTP client that works on macOS and Linux.

## 1. Install msmtp

```bash
# macOS
brew install msmtp

# Debian/Ubuntu
sudo apt install msmtp msmtp-mta
```

## 2. Configure SMTP

Create `~/.msmtprc`:

```
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log

account        default
host           smtp.gmail.com
port           587
from           your-email@example.com
user           your-email@example.com
passwordeval   security find-generic-password -s msmtp -w
```

Lock permissions:

```bash
chmod 600 ~/.msmtprc
```

### Platform-specific `passwordeval`

The `passwordeval` line tells msmtp how to fetch the password **at send-time** from the system keychain. The password is never stored in a file.

| Platform | passwordeval | Store command |
|---|---|---|
| macOS | `security find-generic-password -s msmtp -w` | `security add-generic-password -s msmtp -a your-email@example.com -w` |
| Linux (GNOME) | `secret-tool lookup service msmtp` | `secret-tool store --label=msmtp service msmtp user your-email@example.com` |
| Linux (pass) | `pass show msmtp` | `pass insert msmtp` |

### Platform-specific `tls_trust_file`

| Platform | Path |
|---|---|
| macOS (Homebrew) | `/opt/homebrew/etc/openssl@3/cert.pem` or use `tls_starttls on` without `tls_trust_file` |
| Debian/Ubuntu | `/etc/ssl/certs/ca-certificates.crt` |
| Alpine | `/etc/ssl/certs/ca-certificates.crt` |

### Gmail-specific notes

If using Gmail, you need an **App Password** (not your regular password):
1. Go to https://myaccount.google.com/apppasswords
2. Generate an app password for "Mail"
3. Store it in the keychain using the store command above

## 3. Configure notification recipient

Edit `notification-config.json` in this folder:

```json
{
  "from": {
    "name": "Virtual Architect",
    "address": "your-email@example.com"
  },
  "to": "your-email@example.com",
  "subjectPrefix": "[VA]"
}
```

## 4. Test

```bash
echo "Test from Virtual Architect" | msmtp your-email@example.com
```

## Authentication Model

You authenticate **once** during setup. After that, every send is fully automatic — no prompts, no interaction.

### How it works

1. **One-time setup**: You store the SMTP password in the system keychain (step 2 above). This is the only time you enter the password.
2. **First send**: On macOS, Keychain may show a dialog asking whether to allow `msmtp` (or `security`) to access the stored password. Click **"Always Allow"**. On Linux with `secret-tool`, the keyring is unlocked when you log in — no extra prompt.
3. **Every subsequent send**: `msmtp` calls `passwordeval`, the keychain returns the password silently, the email is sent. No user interaction at all.

This means `/loop 5m /loop-watch-sources` can fire and send emails unattended — after the one-time setup, the loop never blocks on authentication.

### If the keychain locks

- **macOS**: Keychain stays unlocked while you're logged in. It locks on sleep/logout. If locked, `msmtp` will fail silently (the loop logs the error but doesn't block). Emails resume when you log back in.
- **Linux (GNOME Keyring)**: Unlocked at login. Same behavior — emails resume after re-login.
- **Linux (pass/gpg)**: GPG agent caches the passphrase. If the agent expires, `msmtp` fails until you unlock gpg again.

## Security Model

- **SMTP password**: Stored in system keychain only. Retrieved by msmtp at send-time via `passwordeval`. Never written to a file. Not readable by Claude Code or any AI agent — keychain access is granted to `msmtp`/`security` binaries, not to the calling shell session.
- **~/.msmtprc**: Contains SMTP host/port/user but NO password. Locked to `chmod 600`.
- **notification-config.json**: Contains only email addresses (no secrets). Readable by the skill.
