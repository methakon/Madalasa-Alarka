-- Additive guards for the unapproved metadata-only enhancement stores.
-- No pass issuance, non-account location bearer, archive delivery or capture
-- handler is enabled by these constraints. Preserve published 0016 bytes.
DROP POLICY pickup_pass_owner_read ON ap_m1.child_pickup_viewer_passes;
CREATE POLICY pickup_pass_owner_read ON ap_m1.child_pickup_viewer_passes
 FOR SELECT TO ap_m1_api USING (
  created_by=ap_m1.ctx_principal()
  AND ap_m1.has_child_scope_v2(child_id,'VIEW_LOCATION')
  AND ap_m1.has_consent(child_id,'LOCATION')
  AND NOT ap_m1.child_deleted(child_id)
 );
ALTER TABLE ap_m1.child_pickup_viewer_passes
 ADD CONSTRAINT pickup_view_count_bounded CHECK(view_count<=max_views),
 ADD CONSTRAINT pickup_revocation_pair CHECK(is_revoked=(revoked_at IS NOT NULL));
ALTER TABLE ap_m1.compliance_export_bundles
 ADD CONSTRAINT compliance_case_child_binding FOREIGN KEY(child_id,case_id) REFERENCES ap_m1.admin_cases(child_id,id),
 ADD CONSTRAINT compliance_family_child_binding FOREIGN KEY(target_family_id,child_id) REFERENCES ap_m1.children(family_id,id),
 ADD CONSTRAINT compliance_case_requires_child CHECK(case_id IS NULL OR child_id IS NOT NULL),
 ADD CONSTRAINT compliance_download_count_bounded CHECK(download_count<=max_downloads),
 ADD CONSTRAINT compliance_digest_hex CHECK(file_archive_sha256 IS NULL OR file_archive_sha256 ~ '^[0-9A-Fa-f]{64}$');
