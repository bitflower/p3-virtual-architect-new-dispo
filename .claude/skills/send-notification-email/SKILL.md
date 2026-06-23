---
name: send-notification-email
description: Send a plain-text notification email via msmtp. Generic utility used by loop skills to deliver change summaries. Requires msmtp to be installed and configured — see README.md in this folder.
allowed-tools: Bash,Read
---

# Send Notification Email

Generic email sending utility. Takes a subject and body, constructs a proper email message, and pipes it to `msmtp`.

## When to Use

- Called by other skills (e.g. `/loop-watch-sources`) to deliver notifications
- User asks to "email me" or "send a notification"
- NOT for drafting status update emails — use `/send-status-update-mail` for that

## Arguments

```
/send-notification-email <subject> <body>
```

Both subject and body are passed as string arguments by the calling skill.

## How It Works

### Step 1 — Load config

Read `.claude/skills/send-notification-email/notification-config.json` for sender/recipient settings.

### Step 2 — Verify msmtp is available

```bash
command -v msmtp >/dev/null 2>&1
```

If not found, report error: "msmtp is not installed. See .claude/skills/send-notification-email/README.md for setup instructions." and stop.

### Step 3 — Construct and send

Build a properly formatted email and pipe to msmtp:

```bash
printf 'From: %s <%s>\nTo: %s\nSubject: %s\nContent-Type: text/plain; charset=utf-8\nX-Mailer: Virtual Architect\n\n%s\n' \
  "$FROM_NAME" "$FROM_ADDR" "$TO_ADDR" "$SUBJECT" "$BODY" \
  | msmtp "$TO_ADDR"
```

### Step 4 — Report

- On success: report "Email sent to {to}" (one line, no more)
- On failure: report the msmtp error output for debugging

## Security

- This skill MUST NOT read `~/.msmtprc` or attempt to access SMTP credentials
- This skill MUST NOT read from the system keychain
- The only file this skill reads is `notification-config.json` (which contains no secrets — just email addresses)
- msmtp handles credential retrieval internally via its own `passwordeval` directive
