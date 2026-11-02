-- Migration 0016: Temporary Child Pickup Viewer Passes and DSAR Compliance Bundles
-- Fulfills Figma screens P-39/P-40 (Pickup Pass) and ADM-15/ADM-16 (Compliance & DSAR Export)
-- Official norms: DPDP Section 9, Google Play Families Data Safety, Fail-Closed Security

-- 1. Temporary Pickup Passes (45-minute strict duration, single child, non-account recipient)
CREATE TABLE ap_m1.child_pickup_viewer_passes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 child_id uuid NOT NULL REFERENCES ap_m1.children(id) ON DELETE CASCADE,
 created_by uuid NOT NULL REFERENCES ap_m1.parent_principals(id),
 pass_token_hash bytea NOT NULL UNIQUE CHECK(octet_length(pass_token_hash)=32),
 recipient_phone_hash bytea CHECK(recipient_phone_hash IS NULL OR octet_length(recipient_phone_hash)=32),
 current_location_only boolean NOT NULL DEFAULT true CHECK(current_location_only=true),
 max_views integer NOT NULL DEFAULT 10 CHECK(max_views BETWEEN 1 AND 50),
 view_count integer NOT NULL DEFAULT 0 CHECK(view_count>=0),
 is_revoked boolean NOT NULL DEFAULT false,
 revoked_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL,
 CHECK(expires_at > created_at),
 CHECK(expires_at <= created_at + interval '45 minutes')
);

CREATE INDEX pickup_pass_child_idx ON ap_m1.child_pickup_viewer_passes(child_id, expires_at);
CREATE INDEX pickup_pass_token_idx ON ap_m1.child_pickup_viewer_passes(pass_token_hash);

ALTER TABLE ap_m1.child_pickup_viewer_passes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.child_pickup_viewer_passes FORCE ROW LEVEL SECURITY;

CREATE POLICY pickup_pass_owner_read ON ap_m1.child_pickup_viewer_passes FOR SELECT TO ap_m1_api
 USING(created_by = ap_m1.ctx_principal() AND NOT ap_m1.child_deleted(child_id));

CREATE POLICY pickup_pass_bearer_read ON ap_m1.child_pickup_viewer_passes FOR SELECT TO ap_m1_auth
 USING(NOT is_revoked AND expires_at > clock_timestamp() AND view_count < max_views);


-- 2. Compliance Export Bundles (DSAR and regulatory audit archive packaging)
CREATE TABLE ap_m1.compliance_export_bundles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 case_id uuid REFERENCES ap_m1.admin_cases(id),
 requested_by_admin uuid NOT NULL REFERENCES ap_m1.admin_accounts(id),
 export_type text NOT NULL CHECK(export_type IN ('DSAR','LAWFUL_AUTHORITY','REGULATORY_AUDIT','DATA_PORTABILITY')),
 target_family_id uuid REFERENCES ap_m1.families(id),
 child_id uuid REFERENCES ap_m1.children(id),
 export_status text NOT NULL DEFAULT 'REQUESTED' CHECK(export_status IN ('REQUESTED','PROCESSING','COMPLETED','EXPIRED','FAILED')),
 file_archive_sha256 text CHECK(file_archive_sha256 IS NULL OR length(file_archive_sha256)=64),
 max_downloads integer NOT NULL DEFAULT 3 CHECK(max_downloads BETWEEN 1 AND 10),
 download_count integer NOT NULL DEFAULT 0 CHECK(download_count>=0),
 created_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz,
 expires_at timestamptz NOT NULL,
 CHECK(expires_at > created_at)
);

CREATE INDEX compliance_bundle_case_idx ON ap_m1.compliance_export_bundles(case_id);
CREATE INDEX compliance_bundle_admin_idx ON ap_m1.compliance_export_bundles(requested_by_admin);

ALTER TABLE ap_m1.compliance_export_bundles ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.compliance_export_bundles FORCE ROW LEVEL SECURITY;

CREATE POLICY compliance_bundle_admin_read ON ap_m1.compliance_export_bundles FOR SELECT TO ap_m1_api
 USING(requested_by_admin = ap_m1.ctx_admin() AND ap_m1.has_admin_permission('SUPPORT_REPLY'));


-- 3. Screen Alignment Column Modifications
-- support_tickets: add category (BO-06)
ALTER TABLE ap_m1.support_tickets ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'GENERAL' CHECK(category IN ('GENERAL','BILLING','TECHNICAL','SAFETY','LEGAL'));

-- admin_profiles: add verification_method (BO-02/BO-02V)
ALTER TABLE ap_m1.admin_profiles ADD COLUMN IF NOT EXISTS verification_method text NOT NULL DEFAULT 'EMAIL_OTP' CHECK(verification_method IN ('EMAIL_OTP','HARDWARE_KEY','OIDC_PASSKEY'));

-- named_places: add address_label, icon_symbol (P-24)
ALTER TABLE ap_m1.named_places ADD COLUMN IF NOT EXISTS address_label text NOT NULL DEFAULT '' CHECK(length(address_label)<=250);
ALTER TABLE ap_m1.named_places ADD COLUMN IF NOT EXISTS icon_symbol text NOT NULL DEFAULT 'place' CHECK(length(icon_symbol)<=50);

-- admin_action_audit: add case_docket_id, masked_target_account (BO-08)
ALTER TABLE ap_m1.admin_action_audit ADD COLUMN IF NOT EXISTS case_docket_id text CHECK(case_docket_id IS NULL OR length(case_docket_id)<=64);
ALTER TABLE ap_m1.admin_action_audit ADD COLUMN IF NOT EXISTS masked_target_account text CHECK(masked_target_account IS NULL OR length(masked_target_account)<=128);


-- 4. Grants and Erasure Inventory Registration
GRANT SELECT ON ap_m1.child_pickup_viewer_passes TO ap_m1_api, ap_m1_auth;
GRANT SELECT, INSERT, UPDATE, DELETE ON ap_m1.child_pickup_viewer_passes TO ap_db_executor;
GRANT SELECT ON ap_m1.compliance_export_bundles TO ap_m1_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON ap_m1.compliance_export_bundles TO ap_db_executor;

GRANT INSERT,UPDATE,DELETE ON ap_m1.erasure_store_inventory TO ap_db_executor;
SET LOCAL ROLE ap_db_executor;
INSERT INTO ap_m1.erasure_store_inventory(table_name, key_kind, purge_order) VALUES
 ('child_pickup_viewer_passes', 'CHILD', 295),
 ('compliance_export_bundles', 'CHILD', 296)
 ON CONFLICT(table_name) DO UPDATE SET key_kind=EXCLUDED.key_kind, purge_order=EXCLUDED.purge_order;
RESET ROLE;
REVOKE INSERT,UPDATE,DELETE ON ap_m1.erasure_store_inventory FROM ap_db_executor;

-- 5. Device Credential Renewal Challenges (single-use cryptographic key rotation)
CREATE TABLE ap_m1.credential_renewal_challenges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 device_id uuid NOT NULL REFERENCES ap_m1.devices(id) ON DELETE CASCADE,
 key_id text NOT NULL CHECK(length(key_id) BETWEEN 1 AND 64),
 nonce_sha256 text NOT NULL CHECK(length(nonce_sha256)=64),
 created_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL,
 consumed_at timestamptz,
 redeemed_at timestamptz,
 CHECK(expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS credential_renewal_device_idx ON ap_m1.credential_renewal_challenges(device_id);

ALTER TABLE ap_m1.credential_renewal_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE ap_m1.credential_renewal_challenges FORCE ROW LEVEL SECURITY;

CREATE POLICY credential_renewal_device_read ON ap_m1.credential_renewal_challenges FOR SELECT TO ap_m1_auth
 USING(consumed_at IS NULL AND expires_at > clock_timestamp());

GRANT SELECT, INSERT, UPDATE, DELETE ON ap_m1.credential_renewal_challenges TO ap_db_executor;
GRANT SELECT ON ap_m1.credential_renewal_challenges TO ap_m1_auth;
