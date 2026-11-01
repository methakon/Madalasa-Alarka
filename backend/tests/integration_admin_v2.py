#!/usr/bin/env python3
"""V2 HTTP end-to-end test of the admin back office: login challenge, Google exchange
(test-only synthetic identity build), cookie session, CSRF, owner review, FAQ, support,
billing/usage/audit reads and logout.

Usage: integration_admin_v2.py /path/to/ma_backend   (built with -DMA_SYNTHETIC_AUTH=ON)
Requires the migrated V2 test database (tools/database/manage.py ci-config/create/migrate).

The owner MFA step-up does not exist yet. Where a step-up permission is exercised, this
test sets admin_sessions.mfa_until directly through the privileged test login and says
so; that simulates a FUTURE MFA mechanism and proves nothing about one.
SYNTHETIC DATA ONLY. Never prints cookies, CSRF tokens or nonces.
"""
import json
import re
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import integration_parent_session_v2 as base  # noqa: E402
from integration_parent_session_v2 import expect, error_code, fixtures  # noqa: E402

ORIGIN = 'http://127.0.0.1:5173'
SESSION_COOKIE = '__Host-ma_admin_s'
LOGIN_COOKIE = '__Host-ma_admin_login'


def set_cookies(headers):
    out = {}
    for value in headers.get_all('Set-Cookie') or []:
        name, _, rest = value.partition('=')
        out[name.strip()] = (rest.split(';', 1)[0], value)
    return out


def strict_cookie(raw, max_age=None):
    attrs = {a.strip().lower() for a in raw.split(';')[1:] if a.strip()}
    ok = {'secure', 'httponly', 'path=/', 'samesite=strict'} <= attrs and not any(a.startswith('domain') for a in attrs)
    return ok and (max_age is None or f'max-age={max_age}' in attrs)


class Admin:
    def __init__(self, url, subject, email=None):
        self.url, self.subject = url, subject
        self.email = email or subject + '@example.invalid'
        self.session = self.csrf = None

    def headers(self, csrf=True, origin=True, extra=None):
        h = {}
        if origin:
            h['Origin'] = ORIGIN
        if self.session:
            h['Cookie'] = f'{SESSION_COOKIE}={self.session}'
        if csrf and self.csrf:
            h['X-CSRF-Token'] = self.csrf
        h.update(extra or {})
        return h

    def login(self, expect_status=201):
        status, body, headers = base.call(self.url, 'POST', '/v1/admin/auth/challenge', {'Origin': ORIGIN})
        if status != 201:
            raise base.Failure(f'challenge expected 201, got {status}: {body}')
        state = set_cookies(headers)[LOGIN_COOKIE][0]
        base.SECRETS.extend([body['nonce'], state])
        status, result, headers = base.call(
            self.url, 'POST', '/v1/admin/auth/google',
            {'Origin': ORIGIN, 'Cookie': f'{LOGIN_COOKIE}={state}', 'X-Synthetic-Admin-Subject': self.subject,
             'X-Synthetic-Admin-Email': self.email},
            {'id_token': 'synthetic-test-build', 'nonce': body['nonce']})
        if status != expect_status:
            raise base.Failure(f'admin login expected {expect_status}, got {status}: {result}')
        if status == 201:
            cookies = set_cookies(headers)
            self.session = cookies[SESSION_COOKIE][0]
            self.csrf = result['csrf_token']
            base.SECRETS.extend([self.session, self.csrf])
            self.cookie_raw = cookies[SESSION_COOKIE][1]
            self.cleared_login = cookies.get(LOGIN_COOKIE, ('', ''))[1]
        return result

    def get(self, path, **kw):
        return base.call(self.url, 'GET', path, self.headers(csrf=False, origin=False, **kw))

    def send(self, method, path, body=None, **kw):
        return base.call(self.url, method, path, self.headers(**kw), body)


def simulate_future_mfa(admin):
    """TEST-ONLY stand-in for an unimplemented owner MFA step-up."""
    with fixtures.admin_connection() as a:
        a.execute("UPDATE ap_m1.admin_sessions SET mfa_until=expires_at WHERE token_hash=public.digest(%s,'sha256')",
                  (admin.session,))


def main(binary):
    db = base.database_env()
    f = fixtures.seed_core()
    owner_subject = 'e2e-owner-' + str(uuid.uuid4())
    with fixtures.admin_connection() as a:
        a.execute('INSERT INTO ap_m1.owner_identity_allowlist(issuer,subject) VALUES(%s,%s)',
                  ('https://synthetic.invalid', owner_subject))
        ticket = a.execute("INSERT INTO ap_m1.support_tickets(requester_id,subject) VALUES(%s,'E2E synthetic ticket') "
                           "RETURNING id::text", (f['a'],)).fetchone()[0]

    for label, overrides in [('admin origin with a path', dict(db, MA_ADMIN_ORIGIN=ORIGIN + '/')),
                             ('admin session lifetime above bound', dict(db, MA_ADMIN_SESSION_TTL_SECONDS='3601'))]:
        env = base.base_env(dict(overrides, MA_LISTEN_PORT=str(base.free_port())))
        completed = base.subprocess.run([binary], env=env, stdout=base.subprocess.DEVNULL,
                                        stderr=base.subprocess.DEVNULL, timeout=20)
        expect(completed.returncode == 78, 'startup refused: ' + label)

    with base.server(binary, db) as (url, _):
        expect(error_code(base.call(url, 'POST', '/v1/admin/auth/challenge', {'Origin': ORIGIN}), 503,
                          'SERVICE_UNAVAILABLE'), 'admin login closed when MA_ADMIN_ORIGIN is unset')

    with base.server(binary, dict(db, MA_ADMIN_ORIGIN=ORIGIN)) as (url, _):
        # --- challenge and login negatives
        expect(error_code(base.call(url, 'POST', '/v1/admin/auth/challenge'), 403, 'FORBIDDEN'),
               'challenge requires the admin Origin')
        expect(error_code(base.call(url, 'POST', '/v1/admin/auth/challenge', {'Origin': 'https://evil.invalid'}),
                          403, 'FORBIDDEN'), 'challenge rejects a foreign Origin')
        status, ch, headers = base.call(url, 'POST', '/v1/admin/auth/challenge', {'Origin': ORIGIN})
        login_cookie = set_cookies(headers)[LOGIN_COOKIE]
        base.SECRETS.extend([ch['nonce'], login_cookie[0]])
        expect(status == 201 and re.match('^[0-9a-f]{64}$', ch['nonce']) and strict_cookie(login_cookie[1], 300)
               and headers.get('Cache-Control') == 'no-store', 'challenge sets a strict 5-minute HttpOnly state cookie')
        ident = {'X-Synthetic-Admin-Subject': 'e2e-neg', 'X-Synthetic-Admin-Email': 'neg@example.invalid'}
        body = {'id_token': 'synthetic-test-build', 'nonce': ch['nonce']}
        expect(error_code(base.call(url, 'POST', '/v1/admin/auth/google', dict(ident, Origin=ORIGIN), body),
                          401, 'UNAUTHENTICATED'), 'login without the state cookie is refused')
        _, ch2, h2 = base.call(url, 'POST', '/v1/admin/auth/challenge', {'Origin': ORIGIN})
        other_state = set_cookies(h2)[LOGIN_COOKIE][0]
        base.SECRETS.extend([ch2['nonce'], other_state])
        expect(error_code(base.call(url, 'POST', '/v1/admin/auth/google',
                                    dict(ident, Origin=ORIGIN, Cookie=f'{LOGIN_COOKIE}={other_state}'), body),
                          401, 'UNAUTHENTICATED'), 'nonce bound to another browser state is refused')
        expect(error_code(base.call(url, 'POST', '/v1/admin/auth/google',
                                    dict(ident, Origin=ORIGIN, Cookie=f'{LOGIN_COOKIE}={login_cookie[0]}'),
                                    dict(body, csrf_state='browser-generated')), 400, 'INVALID_REQUEST'),
               'browser-generated csrf_state is not accepted')
        expect(error_code(base.call(url, 'POST', '/v1/admin/auth/google',
                                    dict(ident, Origin=ORIGIN, Cookie=f'{LOGIN_COOKIE}={login_cookie[0]}'),
                                    {'id_token': 'x', 'nonce': uuid.uuid4().hex + uuid.uuid4().hex}),
                          401, 'UNAUTHENTICATED'), 'nonce that was never issued is refused')

        # --- applicant: login, profile, request
        applicant = Admin(url, 'e2e-applicant-' + str(uuid.uuid4()))
        result = applicant.login()
        expect(result['state'] == 'NO_ACCESS' and result['role_codes'] == [] and
               re.match('^[0-9a-f]{64}$', result['csrf_token']), 'applicant login is identity only')
        expect(strict_cookie(applicant.cookie_raw, 1800), 'session cookie is HttpOnly, Secure, SameSite=Strict, Path=/')
        expect('max-age=0' in applicant.cleared_login.lower(), 'login state cookie is cleared after use')
        status, me, _ = applicant.get('/v1/admin/access/me')
        expect(status == 200 and me['state'] == 'NO_ACCESS' and me['role_codes'] == [] and not me['mfa_active'],
               'access/me reports server-side roles only')
        profile = {'full_name': 'E2E Synthetic Applicant', 'contact_email': applicant.email,
                   'privacy_notice_version': 'admin-access-draft-2026-10', 'expected_revision': 0}
        expect(error_code(applicant.send('PUT', '/v1/admin/access/profile', profile, csrf=False), 403, 'FORBIDDEN'),
               'mutation without CSRF token is refused')
        expect(error_code(applicant.send('PUT', '/v1/admin/access/profile', profile,
                                         extra={'X-CSRF-Token': 'f' * 64}), 403, 'FORBIDDEN'),
               'mutation with a forged CSRF token is refused')
        expect(error_code(applicant.send('PUT', '/v1/admin/access/profile', profile, origin=False), 403, 'FORBIDDEN'),
               'mutation without the admin Origin is refused')
        expect(error_code(applicant.send('PUT', '/v1/admin/access/profile', dict(profile, date_of_birth='2000-01-01')),
                          422, 'VALIDATION_FAILED'), 'date of birth is not collected')
        status, saved, _ = applicant.send('PUT', '/v1/admin/access/profile', profile)
        expect(status == 200 and saved['profile_revision'] == 1 and saved['email_verified'],
               'profile saved; contact matching the Google-verified email is verified')
        expect(error_code(applicant.send('PUT', '/v1/admin/access/profile', profile), 409, 'CONFLICT'),
               'stale profile revision is a conflict')
        status, req1, _ = applicant.send('POST', '/v1/admin/access/requests', {'profile_revision': 1})
        status2, req2, _ = applicant.send('POST', '/v1/admin/access/requests', {'profile_revision': 1})
        expect(status == 201 and status2 == 201 and req1['id'] == req2['id'] and req1['state'] == 'PENDING_REVIEW',
               'access request is created once and repeat submits are idempotent')
        expect(error_code(applicant.get('/v1/admin/owner/access-requests'), 403, 'FORBIDDEN'),
               'applicant cannot read the owner queue')

        # --- owner: allowlisted identity, MFA gate, decision
        owner = Admin(url, owner_subject)
        result = owner.login()
        expect(result['state'] == 'ACTIVE' and result['role_codes'] == ['ROOT_OWNER'], 'allowlisted owner login')
        expect(error_code(owner.get('/v1/admin/owner/access-requests'), 403, 'FORBIDDEN'),
               'owner queue requires MFA step-up (not implemented => denied)')
        decision = {'decision': 'APPROVE', 'role_codes': ['FAQ_EDITOR'], 'reason': 'E2E synthetic approval',
                    'expected_revision': 1}
        expect(error_code(owner.send('POST', f"/v1/admin/owner/access-requests/{req1['id']}/decision", decision),
                          403, 'FORBIDDEN'), 'owner decision requires MFA step-up')
        expect(error_code(applicant.send('POST', f"/v1/admin/owner/access-requests/{req1['id']}/decision", decision),
                          403, 'FORBIDDEN'), 'applicant cannot decide its own request')
        simulate_future_mfa(owner)
        status, queue, _ = owner.get('/v1/admin/owner/access-requests')
        listed = {i['id']: i for i in queue['items']} if status == 200 else {}
        expect(req1['id'] in listed and listed[req1['id']]['revision'] == 1, '[simulated MFA] owner sees the request')
        expect(error_code(owner.send('POST', f"/v1/admin/owner/access-requests/{req1['id']}/decision",
                                     dict(decision, expected_revision=0)), 422, 'VALIDATION_FAILED'),
               'expected_revision 0 is rejected')
        expect(error_code(owner.send('POST', f"/v1/admin/owner/access-requests/{req1['id']}/decision",
                                     dict(decision, expected_revision=7)), 409, 'CONFLICT'), 'stale decision revision')
        expect(error_code(owner.send('POST', f"/v1/admin/owner/access-requests/{req1['id']}/decision",
                                     dict(decision, role_codes=['ROOT_OWNER'])), 422, 'VALIDATION_FAILED'),
               'ROOT_OWNER cannot be granted')
        status, decided, _ = owner.send('POST', f"/v1/admin/owner/access-requests/{req1['id']}/decision", decision)
        expect(status == 200 and decided['state'] == 'APPROVED', '[simulated MFA] owner approves with a role')
        expect(error_code(applicant.get('/v1/admin/access/me'), 401, 'UNAUTHENTICATED'),
               'approval revokes the applicant session (epoch)')
        editor = applicant
        result = editor.login()
        expect(result['state'] == 'ACTIVE' and result['role_codes'] == ['FAQ_EDITOR'], 'editor re-login has FAQ_EDITOR')

        # --- FAQ
        expect(error_code(owner.send('POST', '/v1/admin/faqs', {'slug': 'x', 'category': 'c', 'title': 'Title',
                                                                'safe_markdown': 'x'}), 422, 'VALIDATION_FAILED'),
               'invalid slug rejected')
        slug = 'e2e-' + uuid.uuid4().hex[:12]
        status, faq, _ = editor.send('POST', '/v1/admin/faqs', {'slug': slug, 'category': 'Accounts',
                                                               'title': 'How do I sign in', 'safe_markdown': 'Use Google.'})
        expect(status == 201 and faq['revision'] == 1 and faq['status'] == 'DRAFT', 'editor creates an FAQ draft')
        expect(error_code(editor.send('POST', '/v1/admin/faqs', {'slug': slug, 'category': 'Accounts',
                                                                 'title': 'Duplicate', 'safe_markdown': 'x'}),
                          409, 'CONFLICT'), 'duplicate slug is a conflict')
        status, draft2, _ = editor.send('PUT', f"/v1/admin/faqs/{faq['id']}",
                                        {'title': 'How do I sign in?', 'safe_markdown': 'Use Google sign-in.',
                                         'expected_revision': 1})
        expect(status == 200 and draft2['revision'] == 2, 'editor saves a second revision')
        expect(error_code(editor.send('PUT', f"/v1/admin/faqs/{faq['id']}",
                                      {'title': 'Stale', 'safe_markdown': 'x', 'expected_revision': 1}), 409, 'CONFLICT'),
               'stale FAQ revision is a conflict')
        status, item, _ = editor.get(f"/v1/admin/faqs/{faq['id']}")
        expect(status == 200 and item['current_revision_id'] == draft2['current_revision_id']
               and item['published_revision_id'] is None, 'admin FAQ read exposes revision ids')
        publish = {'revision_id': draft2['current_revision_id'], 'expected_revision': 2}
        expect(error_code(editor.send('POST', f"/v1/admin/faqs/{faq['id']}/publish", publish), 403, 'FORBIDDEN'),
               'publish requires MFA step-up')
        status, public, _ = base.call(url, 'GET', '/v1/faqs')
        expect(status == 200 and slug not in {i['slug'] for i in public['items']},
               f'draft is not public (status={status} code={(public or {}).get("code")})')
        simulate_future_mfa(editor)
        status, published, _ = editor.send('POST', f"/v1/admin/faqs/{faq['id']}/publish", publish)
        expect(status == 200 and published['revision'] == 3, '[simulated MFA] editor publishes the exact revision')
        status, public, _ = base.call(url, 'GET', '/v1/faqs')
        items = {i['slug']: i for i in public['items']}
        expect(slug in items and 'current_revision_id' not in items[slug], 'published FAQ is public without editor fields')

        # --- support, billing, usage, audit
        expect(error_code(editor.get('/v1/admin/support/tickets'), 403, 'FORBIDDEN'), 'editor has no support access')
        status, tickets, _ = owner.get('/v1/admin/support/tickets?limit=100')
        expect(status == 200 and ticket in {t['id'] for t in tickets['items']}, 'owner lists support tickets')
        expect(error_code(owner.send('POST', f'/v1/admin/support/tickets/{ticket}/reply',
                                     {'body': '<script>', 'request_id': str(uuid.uuid4())}), 422, 'VALIDATION_FAILED'),
               'markup in a reply is rejected')
        key = str(uuid.uuid4())
        s1, r1, _ = owner.send('POST', f'/v1/admin/support/tickets/{ticket}/reply', {'body': 'Synthetic reply', 'request_id': key})
        s2, r2, _ = owner.send('POST', f'/v1/admin/support/tickets/{ticket}/reply', {'body': 'Synthetic reply', 'request_id': key})
        expect(s1 == 201 and s2 == 201 and r1['id'] == r2['id'], 'reply is idempotent on request_id')
        expect(error_code(owner.send('POST', f'/v1/admin/support/tickets/{ticket}/reply',
                                     {'body': 'Different body', 'request_id': key}), 409, 'CONFLICT'),
               'same request_id with a different body is a conflict')
        status, feed, _ = owner.get(f'/v1/admin/support/tickets/{ticket}/messages')
        expect(status == 200 and [m['author_kind'] for m in feed['items']] == ['ADMIN'], 'owner reads the message feed')
        for path in ('/v1/admin/subscribers', '/v1/admin/usage/parents', '/v1/admin/security/audit'):
            expect(error_code(editor.get(path), 403, 'FORBIDDEN'), 'editor is denied ' + path)
        for path in ('/v1/admin/subscribers', '/v1/admin/usage/parents'):
            status, page, _ = owner.get(path)
            expect(status == 200 and isinstance(page['items'], list), 'owner reads ' + path)
        status, audit, _ = owner.get('/v1/admin/security/audit?limit=100')
        actions = {a['action'] for a in audit['items']} if status == 200 else set()
        expect({'ADMIN_LOGIN', 'ACCESS_DECISION', 'SUPPORT_REPLY'} <= actions, '[simulated MFA] owner reads the audit log')

        # --- CSRF rotation, cross-session CSRF, logout
        expect(error_code(editor.send('DELETE', '/v1/admin/auth/session', extra={'X-CSRF-Token': owner.csrf}),
                          403, 'FORBIDDEN'), "another session's CSRF token is refused")
        old = owner.csrf
        status, rotated, _ = base.call(url, 'POST', '/v1/admin/auth/csrf', owner.headers(csrf=False))
        expect(status == 200 and rotated['csrf_token'] != old, 'CSRF token rotates for page reloads')
        base.SECRETS.append(rotated['csrf_token'])
        expect(error_code(owner.send('DELETE', '/v1/admin/auth/session', extra={'X-CSRF-Token': old}), 403, 'FORBIDDEN'),
               'rotated-out CSRF token is refused')
        owner.csrf = rotated['csrf_token']
        status, _, headers = owner.send('DELETE', '/v1/admin/auth/session')
        expect(status == 204 and 'max-age=0' in set_cookies(headers)[SESSION_COOKIE][1].lower(),
               'logout returns 204 and clears the cookie')
        expect(error_code(owner.get('/v1/admin/access/me'), 401, 'UNAUTHENTICATED'), 'logged-out session is refused')
        expect(error_code(owner.get('/v1/admin/support/tickets'), 401, 'UNAUTHENTICATED'),
               'logged-out session cannot read support')
    print('V2 admin back-office HTTP end-to-end PASS', flush=True)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: integration_admin_v2.py /path/to/ma_backend')
    main(sys.argv[1])
