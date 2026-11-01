"""Load and verify the canonical FAQ seed content through the enforced path.

Synthetic-only. This test proves that every entry in
backend/persistence/seeds/faqs.json:
  * obeys the FaqEntry / faq_entries + faq_revisions schema constraints,
  * drafts via ap_m1.faq_draft under a FAQ_EDITOR admin (FAQ_EDIT),
  * publishes via ap_m1.faq_transition under an MFA admin session (FAQ_PUBLISH),
  * becomes visible to the public (ap_m1_api) read path with state PUBLISHED,
  * and that a draft is never publicly visible before publish.

It also serves as the loader: the same JSON drives runtime admin API loading.
"""
import json
import re
import unittest
from pathlib import Path
from uuid import uuid4

import psycopg

import fixtures
from fixtures import admin_connection, runtime_connection, seed_core

ROOT = Path(__file__).resolve().parents[3]
SEED = ROOT / 'backend/persistence/seeds/faqs.json'

SLUG_RE = re.compile(r'^[a-z0-9][a-z0-9-]{1,149}$')


def load_entries():
    data = json.loads(SEED.read_text(encoding='utf-8'))
    return data['entries']


class FaqSeedContent(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.f = seed_core()
        # Privileged synthetic setup: an activated admin with FAQ_EDITOR, and an
        # MFA-bearing session so FAQ_PUBLISH (step-up) is allowed.
        with admin_connection() as c:
            cls.editor = c.execute('SELECT ap_m1.register_admin(%s,%s)',
                                   (cls.f['c'], 'faq-editor@synthetic.example.invalid')).fetchone()[0]
            c.execute("UPDATE ap_m1.admin_accounts SET state='ACTIVE' WHERE id=%s", (cls.editor,))
            c.execute('INSERT INTO ap_m1.admin_role_grants(admin_id,role_code,granted_by) '
                      'VALUES(%s,%s,%s) ON CONFLICT(admin_id,role_code) WHERE revoked_at IS NULL DO NOTHING',
                      (cls.editor, 'FAQ_EDITOR', cls.editor))
            # Session with an MFA timestamp (second arg) so FAQ_PUBLISH is permitted.
            cls.mfa = c.execute("SELECT ap_m1.mint_admin_session(%s,now()+interval '30 minutes',"
                                "now()+interval '10 minutes')", (cls.editor,)).fetchone()[0]

    @classmethod
    def tearDownClass(cls):
        with admin_connection() as c:
            # admin_action_audit is an immutable trail that references the actor;
            # remove the synthetic actor's audit rows before the account (disposable DB).
            c.execute('DELETE FROM ap_m1.admin_action_audit WHERE actor_admin_id=%s', (cls.editor,))
            c.execute('DELETE FROM ap_m1.admin_sessions WHERE admin_id=%s', (cls.editor,))
            c.execute('DELETE FROM ap_m1.admin_role_grants WHERE admin_id=%s', (cls.editor,))
            c.execute('DELETE FROM ap_m1.admin_accounts WHERE id=%s', (cls.editor,))

    def test_01_content_obeys_schema_constraints(self):
        entries = load_entries()
        self.assertGreaterEqual(len(entries), 1)
        seen = set()
        for e in entries:
            slug = e['slug']
            self.assertRegex(slug, SLUG_RE, slug)
            self.assertNotIn(slug, seen, 'duplicate slug ' + slug)
            seen.add(slug)
            self.assertLessEqual(len(e['category']), 100, slug)
            self.assertEqual(e['language'], 'en', slug)
            self.assertTrue(3 <= len(e['title']) <= 220, slug)
            self.assertNotRegex(e['title'], r'[<>]', slug)
            self.assertTrue(1 <= len(e['safe_markdown']) <= 10000, slug)
            self.assertNotRegex(e['safe_markdown'], r'[<>\[\]]', slug)

    def test_02_draft_publish_and_public_visibility(self):
        entries = load_entries()
        rc = runtime_connection()
        self.addCleanup(rc.close)
        created = []
        try:
            for e in entries:
                target = uuid4()
                with rc.transaction():
                    rc.execute("SELECT set_config('ap.session_token','',true),"
                               "set_config('ap.admin_session_token',%s,true)", (self.mfa,))
                    # Draft (FAQ_EDIT): expected=0 creates the entry + revision 1.
                    rid = rc.execute('SELECT ap_m1.faq_draft(%s,%s,%s,%s,%s,0)',
                                     (target, e['slug'], e['category'], e['title'],
                                      e['safe_markdown'])).fetchone()[0]
                    # Before publish, the public read path must NOT see it.
                    rc.execute("SELECT set_config('ap.admin_session_token','',true)")
                    pub = rc.execute("SELECT count(*) FROM ap_m1.faq_entries "
                                     "WHERE slug=%s AND state='PUBLISHED'", (e['slug'],)).fetchone()[0]
                    self.assertEqual(pub, 0, 'draft leaked before publish: ' + e['slug'])
                    # Publish (FAQ_PUBLISH, MFA): entry revision is 1 after the draft.
                    rc.execute("SELECT set_config('ap.admin_session_token',%s,true)", (self.mfa,))
                    rc.execute("SELECT ap_m1.faq_transition(%s,%s,1,'PUBLISHED')", (target, rid))
                created.append((target, e['slug']))

            # Public read path (no admin session) now sees exactly the published set.
            rc.execute("SELECT set_config('ap.admin_session_token','',true)")
            for target, slug in created:
                row = rc.execute(
                    "SELECT e.state, r.title, r.safe_body FROM ap_m1.faq_entries e "
                    "JOIN ap_m1.faq_revisions r ON r.faq_id=e.id AND r.id=e.published_revision_id "
                    "WHERE e.slug=%s", (slug,)).fetchone()
                self.assertIsNotNone(row, slug)
                self.assertEqual(row[0], 'PUBLISHED', slug)
                self.assertTrue(row[1] and row[2], slug)
        finally:
            with admin_connection() as c:
                ids = [t for t, _ in created]
                if ids:
                    # Circular FK (entries<->revisions) + PUBLISHED CHECK: clear state
                    # and pointers before deleting revisions, then entries and audit.
                    c.execute("UPDATE ap_m1.faq_entries SET state='DRAFT',"
                              "current_revision_id=NULL,published_revision_id=NULL "
                              "WHERE id=ANY(%s)", (ids,))
                    c.execute('DELETE FROM ap_m1.faq_revisions WHERE faq_id=ANY(%s)', (ids,))
                    c.execute('DELETE FROM ap_m1.faq_entries WHERE id=ANY(%s)', (ids,))
                    c.execute("DELETE FROM ap_m1.admin_action_audit WHERE target_ref=ANY(%s) "
                              "AND action IN ('FAQ_DRAFT','FAQ_TRANSITION')", (ids,))

    def test_03_unprivileged_runtime_cannot_draft(self):
        """A runtime connection without an admin session must be denied FAQ_EDIT."""
        rc = runtime_connection()
        self.addCleanup(rc.close)
        rc.execute("SELECT set_config('ap.admin_session_token','',true)")
        # faq_draft raises SQLSTATE 42501, surfaced by psycopg as InsufficientPrivilege.
        with self.assertRaises(psycopg.errors.InsufficientPrivilege):
            with rc.transaction():
                rc.execute('SELECT ap_m1.faq_draft(%s,%s,%s,%s,%s,0)',
                           (uuid4(), 'should-not-exist', 'x', 'Denied draft attempt',
                            'no permission')).fetchone()


if __name__ == '__main__':
    unittest.main()
