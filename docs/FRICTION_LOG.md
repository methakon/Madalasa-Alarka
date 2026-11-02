# Madalasa–Alarka — Development Friction Log

**Project:** Madalasa–Alarka (Amar-Pola)  
**Scope:** Local Development, Multi-Worker Synchronization, Android Hardware, and Backend Infrastructure  
**Last updated:** 2026-11-03  

This log records verified friction, architectural gotchas, toolchain discrepancies, and operational resolutions encountered during local implementation. Every incident records the date, context, symptoms, root cause, severity, workaround, and current resolution status.

---

## Incident 1: Isolated Test PostgreSQL Container Port (15433 vs 15432)

**Date:** 2026-11-02 / 2026-11-03  
**Tasks:** Database integration test suites across Phases 07, 08, 09, and 10  

**Context:**  
The repository provides a dedicated test runner (`tools/database/manage.py`) that separates persistent development data from isolated test execution.

**Symptom:**  
Running `.venv/bin/python tools/database/manage.py test` or direct test scripts produced:
```
psycopg.OperationalError: connection failed: connection to server at "127.0.0.1", port 15433 failed: Connection refused
```

**Root Cause:**  
`manage.py start` starts the persistent development database container (`madalasa-local-postgres`) on port `15432`. However, the test fixtures strictly require the ephemeral, RAM-backed test container (`madalasa-memory-test-postgres`) listening on port `15433`.

**Severity:** Important (blocks local database test execution)  

**Workaround & Resolution:**  
1. Boot the memory test container explicitly before running test suites:
   ```bash
   .venv/bin/python tools/database/manage.py start-memory-test
   .venv/bin/python tools/database/manage.py migrate --database test
   ```
2. Both persistent dev (`15432`) and RAM-backed test (`15433`) can run concurrently without cross-contamination.  
**Status:** Resolved and documented.

---

## Incident 2: Multi-Branch Worktree Isolation & Documentation Leaks

**Date:** 2026-10-31 to 2026-11-02  
**Tasks:** Branch Governance and Cross-Stream Synchronization  

**Context:**  
The project enforces five permanent working branches (`api`, `parent`, `child`, `admin-web`, `dev`) and one canonical branch (`main`). Documentation changes are permitted exclusively on `main`.

**Symptom:**  
Cross-branch commits on implementation branches accidentally carried modified files under `docs/**` or encountered merge conflicts when switching branches in a single worktree.

**Root Cause:**  
Switching branches in a single directory created dirty worktree artifacts and carried uncommitted doc edits across branch boundaries.

**Severity:** Critical (fails CI branch governance and documentation gates)  

**Workaround & Resolution:**  
1. Established dedicated, permanent disk worktrees for each branch:
   - `/home/swarna-sekhar-dhar/projects/mypola/Amar-Pola` (`api`)
   - `/home/swarna-sekhar-dhar/projects/mypola/Madalasa-parent` (`parent`)
   - `/home/swarna-sekhar-dhar/projects/mypola/Alarka-child` (`child`)
   - `/home/swarna-sekhar-dhar/projects/mypola/Amar-Pola-dev` (`dev`)
   - `/home/swarna-sekhar-dhar/projects/mypola/Madalasa-Alarka-main` (`main`)
2. Enforced the hard prework gate: `bash docs/tools/sync_work_branch.sh <branch>` before starting any work slice.  
**Status:** Resolved; automated in prework script.

---

## Incident 3: Android DPC Device Owner Security Restrictions on Physical Devices

**Date:** 2026-11-02  
**Tasks:** L05-011 and L09-009 (Real Device Management & Permissions)  

**Context:**  
The Alarka child application includes enterprise DPC capabilities for managed test devices, which require `DeviceOwnerApp` status.

**Symptom:**  
On ordinary physical development devices (e.g., Xiaomi Mi A3, Android 11), Android blocks dynamic provisioning of Device Owner status without a factory reset and zero accounts registered.

**Root Cause:**  
Android platform security strictly prevents apps from claiming Device Owner status on an active consumer device.

**Severity:** Moderate (expected Android security boundary)  

**Workaround & Resolution:**  
1. Implemented `DeviceManagementModeDetector` and `DeviceOwnerLabOnlyTest` to assert that the app truthfully detects `STANDARD` mode and never self-claims Device Owner status on ordinary hardware.
2. Verified that DPC features remain dormant and fail safe unless genuine provisioning was completed on a wiped lab phone.  
**Status:** Resolved; verified via physical device test `connectedDebugAndroidTest`.

---

## Incident 4: Database Role Separation & Direct Table Writes in Test Fixtures

**Date:** 2026-11-02  
**Tasks:** L09-005 (Device Health Staleness Reporting)  

**Context:**  
Database functions run under PostgreSQL Row Level Security (RLS) with least-privilege executor roles (`ap_db_executor`, `ap_device`, `ap_parent`).

**Symptom:**  
A test setting `SET LOCAL ROLE ap_db_executor` failed when attempting `INSERT INTO ap_m1.device_health` because `ap_db_executor` is granted `SELECT` and `UPDATE` on health metrics, but raw intake is handled via specific functions or administrator ingestion.

**Root Cause:**  
Synthetic test fixtures attempted to bypass role-based access control rather than testing the schema constraints directly.

**Severity:** Low (test setup nuance)  

**Workaround & Resolution:**  
Separated schema invariant testing (executed via privileged admin connection) from transactional security definer validation (executed via runtime user connections).  
**Status:** Resolved in `test_safety_sos.py`.

---

## Incident 5: Two-Stage Competition Submission Lifecycle (Kaggle ARC-AGI-2)

**Date:** 2026-11-02  
**Tasks:** ARC Prize 2026 Notebook Dispatch & Evaluation  

**Context:**  
Kaggle code competitions require running notebooks in a sandboxed GPU environment before submitting predictions to the leaderboard.

**Symptom:**  
After pushing a notebook version via the API, the run did not appear on `https://www.kaggle.com/competitions/arc-prize-2026-arc-agi-2/submissions`.

**Root Cause:**  
Kaggle treats notebook commit runs (Stage 1) and competition evaluation reruns (Stage 2) as distinct entities:
- Stage 1 runs as a kernel build and is visible only on the notebook's code page.
- Stage 2 (which appears on `/submissions` as `PENDING`) only begins after Stage 1 finishes, produces `submission.json`, and triggers the competition submission endpoint.

**Severity:** Moderate (operational confusion)  

**Workaround & Resolution:**  
Deployed `watch_v11.sh` to poll kernel status and automatically submit `submission.json` via the SDK as soon as `KernelWorkerStatus.COMPLETE` is detected.  
**Status:** Operational.
