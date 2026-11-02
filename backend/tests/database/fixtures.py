"""Synthetic-only PostgreSQL fixtures; never print connection strings or bearers.

Use real separate logins, not SET ROLE. The ignored connection.json may contain
admin_dsn/runtime_dsn/auth_dsn (or MA_* names). seed_core requires a privileged
connection and deliberately opts this disposable database into synthetic tests.
"""
from contextlib import contextmanager
import json
import os
from pathlib import Path
from uuid import UUID, uuid4, uuid5
import psycopg

ROOT = Path(__file__).resolve().parents[3]
# Stable within a run, unique across runs: never resurrect identifiers in the
# independent erasure ledger. Set MA_TEST_NAMESPACE to reproduce an exact run.
NS = UUID(os.environ['MA_TEST_NAMESPACE']) if os.environ.get('MA_TEST_NAMESPACE') else uuid4()


def ci_mode():
    """Mirror of the runner gate; a partial opt-in fails closed, never ignored."""
    if os.environ.get('MA_LOCAL_DB_CI') != '1':
        return False
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('MA_CI_SYNTHETIC') != '1':
        raise ValueError('MA_LOCAL_DB_CI requires GITHUB_ACTIONS=true and MA_CI_SYNTHETIC=1')
    return True


_CI_VERIFIED = set()


def validate_test_dsn(dsn):
    """Reject unsafe direct unittest targets before opening any connection."""
    values = psycopg.conninfo.conninfo_to_dict(dsn)
    ci = ci_mode()
    ports = ('15432','15433','5432') if ci else ('15432','15433')
    alternate = os.environ.get('MA_LOCAL_DB_DIR')
    # CI authenticates the Actions service from the server itself; there is no
    # local container to inspect, so an ambient alternate-config checkout must
    # not take precedence over the CI identity proof.
    if alternate and not ci:
        import sys
        if str(ROOT) not in sys.path:
            sys.path.insert(0, str(ROOT))
        from tools.database import manage
        local = manage.local_directory()
        if local != (ROOT / '.local-db').resolve():
            if local != manage.LOCAL.resolve():
                raise ValueError('Database config environment changed after runner import')
            manage.validate_target(values)
            manage.assert_container('test')
            return dsn
    if (values.get('host') not in ('127.0.0.1','localhost','::1')
        or values.get('hostaddr',values.get('host')) not in ('127.0.0.1','localhost','::1')
        or values.get('port') not in ports
        or values.get('dbname') != 'madalasa_alarka_test'
        or values.get('service')):
        raise ValueError('Tests require the dedicated loopback test database on port ' + ' or '.join(ports))
    if ci:
        verify_ci_target_once()
    return dsn


def verify_ci_target_once():
    """Prove the Actions service identity once, not once per fixture connection."""
    key = os.environ.get('MA_LOCAL_DB_CONFIG', '')
    if not key or key in _CI_VERIFIED:
        return None
    import sys
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))
    from tools.database import manage
    manage.assert_ci_database('test')
    _CI_VERIFIED.add(key)
    return key


def _dsn(kind):
    env = {'admin': 'MA_TEST_DSN', 'runtime': 'MA_RUNTIME_DSN', 'auth': 'MA_AUTH_DSN'}[kind]
    if os.environ.get(env):
        return validate_test_dsn(os.environ[env])
    if os.environ.get('MA_LOCAL_DB_CONFIG'):
        path = Path(os.environ['MA_LOCAL_DB_CONFIG'])
    elif os.environ.get('MA_LOCAL_DB_DIR'):
        import sys
        if str(ROOT) not in sys.path:
            sys.path.insert(0,str(ROOT))
        from tools.database import manage
        path = manage.local_directory() / 'connection.json'
    else:
        path = ROOT / '.local-db' / 'connection.json'
    if not path.exists():
        raise RuntimeError(f'{env} or ignored .local-db/connection.json is required')
    if path.stat().st_mode & 0o077:
        raise RuntimeError('connection.json must be private (chmod 600)')
    config = json.loads(path.read_text())
    # Bootstrap uses nested dev/test maps. Never default tests to dev.
    config = config.get('test', config)
    if isinstance(config.get(kind), str):
        return validate_test_dsn(config[kind])
    for key in (env, kind + '_dsn', {'admin': 'test_dsn', 'runtime': 'runtime', 'auth': 'auth'}[kind]):
        if isinstance(config.get(key), str):
            return validate_test_dsn(config[key])
    raise RuntimeError(f'connection.json missing {kind}_dsn')


def admin_connection(**kwargs):
    return psycopg.connect(_dsn('admin'), **kwargs)


def runtime_connection(**kwargs):
    return psycopg.connect(_dsn('runtime'), **kwargs)


def auth_connection(**kwargs):
    return psycopg.connect(_dsn('auth'), **kwargs)


def mint_session(principal, family=None, device=None, lifetime='1 hour'):
    with auth_connection() as issuer:
        return issuer.execute('SELECT ap_m1.mint_session(%s,%s,%s,%s::interval)',
                              (principal, family, device, lifetime)).fetchone()[0]


def as_parent(conn, actor_uuid, family_uuid=None, device_uuid=None):
    """Bind trusted opaque bearer to caller's current, non-autocommit transaction.

    This is intentionally a setter, not a transaction manager: existing tests can
    call it before subsequent queries and retain context until commit/rollback.
    """
    if conn.autocommit:
        raise ValueError('as_parent requires a live non-autocommit transaction')
    token = mint_session(actor_uuid, family_uuid, device_uuid)
    conn.execute("SELECT set_config('ap.session_token',%s,true)", (token,))
    return token


@contextmanager
def parent_connection(actor_uuid, family_uuid=None):
    with runtime_connection() as conn:
        as_parent(conn, actor_uuid, family_uuid)
        yield conn
        conn.rollback()


def seed_device_key(conn, device, key_id=None):
    """Privileged synthetic record only; NOT enrollment or proof-of-possession.

    Fingerprint the deliberately invented device SPKI already seeded by tests.
    This helper does not verify real signatures or activate pending enrollment.
    """
    key_id = key_id or uuid5(NS, 'synthetic-key-' + str(device))
    conn.execute("INSERT INTO ap_m1.device_key_records(key_id,device_id,fingerprint_sha256,state) "
                 "SELECT %s,id,public.digest(spki_public_key,'sha256'),'ACTIVE' "
                 "FROM ap_m1.devices WHERE id=%s ON CONFLICT DO NOTHING", (key_id, device))
    return key_id


def seed_core(conn=None):
    """Create deterministic invented actors; no M1 legacy grant is approved.

    Calling this privileged helper is explicit database-local synthetic opt-in.
    API/issuer cannot write local_test_settings, reviews, consents or identities.
    Optional caller connection keeps all seed writes in caller's transaction.
    """
    if conn is None:
        with admin_connection() as own:
            return seed_core(own)
    names = ('a b c family_a family_b child_a sibling_a child_b device_a '
             'consent_a review_a review_b review_c consent_b').split()
    f = {name: uuid5(NS, name) for name in names}
    conn.execute("INSERT INTO ap_m1.local_test_settings(singleton,enabled) VALUES(true,true) "
                 "ON CONFLICT(singleton) DO UPDATE SET enabled=true")
    for actor in ('a', 'b', 'c'):
        conn.execute('INSERT INTO ap_m1.parent_principals(id,oidc_issuer,oidc_subject) VALUES(%s,%s,%s) ON CONFLICT DO NOTHING',
                     (f[actor], 'https://synthetic.example.invalid', 'fixture-' + str(f[actor])))
        conn.execute("INSERT INTO ap_m1.trusted_principal_verifications(principal_id,state) VALUES(%s,'LOCAL_TEST_APPROVED') ON CONFLICT DO NOTHING", (f[actor],))
    for family, actor in [('family_a', 'a'), ('family_b', 'b')]:
        conn.execute('INSERT INTO ap_m1.families(id,label) VALUES(%s,%s) ON CONFLICT DO NOTHING', (f[family], 'synthetic ' + family))
        conn.execute("INSERT INTO ap_m1.guardian_memberships(family_id,principal_id,membership_role) VALUES(%s,%s,'OWNER') ON CONFLICT DO NOTHING", (f[family], f[actor]))
    for child, family in [('child_a','family_a'), ('sibling_a','family_a'), ('child_b','family_b')]:
        conn.execute('INSERT INTO ap_m1.children(id,family_id,alias) VALUES(%s,%s,%s) ON CONFLICT DO NOTHING', (f[child], f[family], 'synthetic ' + child))
    for review, child, actor in [('review_a','child_a','a'), ('review_b','child_a','b'), ('review_c','child_b','b')]:
        conn.execute("INSERT INTO ap_m1.child_authority_reviews(id,child_id,adult_id,state,lawful_basis_version,method_code,reviewed_at,expires_at) VALUES(%s,%s,%s,'LOCAL_TEST_APPROVED','synthetic-v1','SYNTHETIC_FIXTURE',now(),now()+interval '1 day') ON CONFLICT DO NOTHING", (f[review],f[child],f[actor]))
    for consent, child, actor, review in [('consent_a','child_a','a','review_a'),('consent_b','child_b','b','review_c')]:
        for purpose in ('CORE','LOCATION','USAGE','MEDIA'):
            cid = f[consent] if purpose == 'CORE' else uuid5(NS, consent + purpose)
            conn.execute("INSERT INTO ap_m1.consent_records(id,child_id,adult_id,purpose,status,authority_review_id,notice_version,legal_state,expires_at) VALUES(%s,%s,%s,%s,'GRANTED',%s,'synthetic-v1','LOCAL_TEST_APPROVED',now()+interval '1 day') ON CONFLICT DO NOTHING", (cid,f[child],f[actor],purpose,f[review]))
    scopes = ('VIEW_CHILD_PROFILE','VIEW_CHILD_DEVICES','PAIR_DEVICE','REVOKE_CHILD_DEVICE','MANAGE_CHILD_GRANTS','VIEW_LOCATION','VIEW_HISTORY','MANAGE_TRIPS','VIEW_ALERTS','MANAGE_ALERTS','VIEW_USAGE','MANAGE_COMMANDS','VIEW_MEDIA','REQUEST_MEDIA','MANAGE_CONSENT')
    for child, actor, consent, review in [('child_a','a','consent_a','review_a'),('child_b','b','consent_b','review_c')]:
        for scope in scopes:
            conn.execute('INSERT INTO ap_m1.child_access_grants_v2(child_id,adult_id,scope,consent_record_id,authority_review_id,issued_by) VALUES(%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING', (f[child],f[actor],scope,f[consent],f[review],f[actor]))
    conn.execute("INSERT INTO ap_m1.devices(id,family_id,child_id,spki_public_key,enrollment_state) VALUES(%s,%s,%s,%s,'ACTIVE') ON CONFLICT(id) DO UPDATE SET spki_public_key=excluded.spki_public_key", (f['device_a'],f['family_a'],f['child_a'],('SYNTHETIC-NOT-CRYPTO-' + str(f['device_a'])).encode()*2))
    f['device_key_a'] = seed_device_key(conn, f['device_a'])
    return f
