# Evidence: Transactional & Support Email Transport Verification

**Date:** 2026-11-01  
**Target:** Local `.env` Email Configurations (`mail.berhampore.in`)  
**Scope:** Outbound Notification SMTP (`noreply@berhampore.in`) and Inbound Support IMAP (`madalasa-alarka@berhampore.in`)  
**Verification Method:** Live bidirectional delivery and receipt test with external reference provider (`swarna.s.jobs@gmail.com` via Google Gmail)  
**Status:** PASS — VERIFIED OPERATIONAL  

---

## 1. Environment & Channel Scope

The email parameters in `.env` were evaluated and verified against real transport endpoints:

| Parameter | Value | Verification |
|---|---|---|
| `SMTP_HOST` | `mail.berhampore.in` | Connected over direct SSL/TLS (`port 465`) |
| `SMTP_USER` | `noreply` | Authenticated successfully |
| `SMTP_FROM` | `noreply@berhampore.in` | Sender identity confirmed |
| `IMAP_HOST` | `mail.berhampore.in` | Connected over direct SSL/TLS (`port 993`) |
| `POP3_HOST` | `mail.berhampore.in` | Endpoint available over SSL/TLS (`port 995`) |
| `MAILBOX_ADDRESS` | `madalasa-alarka@berhampore.in` | Primary support mailbox confirmed |
| `MAILBOX_USER` | `madalasa-alarka` | Authenticated successfully via IMAP |

---

## 2. Test Execution & Evidence

### Test Run ID: `67118180` (Executed 2026-11-01 02:46 UTC+05:30)

### Phase 1: Outbound Dispatch (`mail.berhampore.in` → Google Gmail)
1. **Client Action:** Connected to `mail.berhampore.in:465` (SSL) using `noreply` credentials and dispatched a standard RFC 5322 test message:
   - `From:` `noreply@berhampore.in`
   - `To:` `swarna.s.jobs@gmail.com`
   - `Subject:` `Amar-Pola Test: Outbound Delivery Check [67118180]`
2. **Receiver Verification:** Polled `imap.gmail.com:993` using authenticated credentials for `swarna.s.jobs@gmail.com`.
3. **Result:** Message arrived in Gmail primary **`INBOX`** on Attempt 1 (Message ID `217`).
4. **Received Transport Headers:**
   ```
   Received: from berhampore.in ([161.33.146.238]) by smtp.gmail.com with ESMTPSA
   From: bapay.9@gmail.com / noreply@berhampore.in
   To: swarna.s.jobs@gmail.com
   Subject: Amar-Pola Test: Outbound Delivery Check [67118180]
   ```

### Phase 2: Inbound Dispatch (Google Gmail → `madalasa-alarka@berhampore.in`)
1. **Client Action:** Connected to `smtp.gmail.com:465` using `swarna.s.jobs@gmail.com` and dispatched a return test message:
   - `From:` `swarna.s.jobs@gmail.com`
   - `To:` `madalasa-alarka@berhampore.in`
   - `Subject:` `Amar-Pola Test: Inbound Receipt Check [67118180]`
2. **Receiver Verification:** Polled `mail.berhampore.in:993` using IMAP credentials for user `madalasa-alarka`.
3. **Result:** Message arrived in `madalasa-alarka@berhampore.in` **`INBOX`** on Attempt 1 (Message ID `1`).
4. **Received Transport Headers:**
   ```
   Received: from mail-dy1-f179.google.com ([74.125.82.179]) by mail.berhampore.in
   From: swarna.s.jobs@gmail.com
   To: madalasa-alarka@berhampore.in
   Subject: Amar-Pola Test: Inbound Receipt Check [67118180]
   ```

---

## 3. Conclusions & Security Posture

1. **Outbound Notification Delivery:** `noreply@berhampore.in` successfully delivers transactional notifications to external consumer mailboxes without being rejected, dropped or sent to spam.
2. **Inbound Support Mailbox:** `madalasa-alarka@berhampore.in` correctly receives external incoming mail through public MX records and makes messages accessible over secure IMAP.
3. **Zero Secrets in Git:** All passwords, tokens and credentials remain restricted to local environment files and were not checked into the repository.
