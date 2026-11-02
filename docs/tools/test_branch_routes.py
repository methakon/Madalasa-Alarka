"""Branch governance policy and negative route tests. No real GitHub mutations."""
import unittest
from branch_routes import config, validate, is_documentation


class BranchRoutesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rules = config()

    def check(self, base, head, *paths, temporary=False):
        return validate(base, head, paths, temporary, self.rules)

    def test_exact_five_work_branches_plus_main(self):
        self.assertEqual(self.rules["permanent_work_branches"],
                         ["api", "parent", "child", "admin-web", "dev"])
        self.assertEqual(self.rules["canonical_branch"], "main")
        self.assertEqual(set(self.rules["branch_origins"]), set(self.rules["permanent_work_branches"]))
        self.assertTrue(all(origin == "main" for origin in self.rules["branch_origins"].values()))
        self.assertEqual(self.rules["documentation_branch"], "main")

    def test_every_workstream_promotes_through_dev(self):
        for head in ("api", "parent", "child", "admin-web"):
            with self.subTest(head=head):
                self.assertEqual([], self.check("dev", head, "backend/tests/test_example.py"))
                self.assertTrue(self.check("main", head, "backend/tests/test_example.py"))

    def test_dev_is_only_normal_code_source_for_main(self):
        self.assertEqual([], self.check("main", "dev", "backend/src/main.cc"))
        self.assertTrue(self.check("dev", "dev", "backend/src/main.cc"))
        self.assertTrue(self.check("main", "unknown", "backend/src/main.cc"))
        self.assertTrue(self.check("release", "dev", "backend/src/main.cc"))

    def test_docs_never_travel_in_code_pr(self):
        docs = ("docs/phases/M1/notes.md", "AGENTS.md", "README.md",
                "CONTRIBUTING.md", ".github/PULL_REQUEST_TEMPLATE.md",
                ".github/workflows/branch-governance.yml")
        for path in docs:
            with self.subTest(path=path):
                self.assertTrue(is_documentation(path, self.rules))
                self.assertTrue(self.check("dev", "api", path))
                self.assertTrue(self.check("main", "dev", path))

    def test_real_web_pages_are_admin_web_implementation(self):
        self.assertFalse(is_documentation("public/legal/terms.html", self.rules))
        self.assertEqual([], self.check("dev", "admin-web", "public/legal/terms.html"))
        self.assertEqual([], self.check("dev", "admin-web", "public/faq/index.html"))
        self.assertTrue(self.check("main", "admin-web", "public/legal/terms.html"))

    def test_temporary_branch_needs_owner_label_and_dev(self):
        self.assertTrue(self.check("dev", "temp/bug-123", "backend/src/change.cc"))
        self.assertEqual([], self.check("dev", "temp/bug-123", "backend/src/change.cc", temporary=True))
        self.assertTrue(self.check("main", "temp/bug-123", "backend/src/change.cc", temporary=True))

    def test_legacy_db_branch_is_preserved_but_requires_dev_gate(self):
        legacy = self.rules["legacy_exception_branch"]
        self.assertTrue(self.check("main", legacy, "backend/persistence/migrations/m.sql", temporary=True))
        self.assertEqual([], self.check("dev", legacy, "backend/persistence/migrations/m.sql", temporary=True))
        self.assertTrue(self.check("dev", legacy, "docs/README.md", temporary=True))

    def test_fail_closed_for_empty_or_unsafe_paths(self):
        self.assertTrue(self.check("dev", "api"))
        for path in ("../docs/test.md", "/etc/passwd", "backend//a.py", "backend/../a.py"):
            with self.subTest(path=path):
                self.assertTrue(self.check("dev", "api", path))

    def test_promotion_retirement_and_signoff_are_explicit(self):
        for key in ("documentation_main_only", "require_dev_approval",
                    "final_verification_required", "require_owner_instruction_for_temp",
                    "delete_temp_only_after_verified_main_integration", "keep_permanent_work_branches"):
            self.assertIs(self.rules[key], True, key)

    def test_owner_prework_pull_both_branches_before_every_segment(self):
        sync = self.rules["prework_sync"]
        self.assertIs(sync["required"], True)
        self.assertEqual(sync["repetition"], ["before_task_start", "before_task_resume", "before_code_pr"])
        self.assertEqual(sync["fetch_refs"], ["main", "dev"])
        self.assertEqual(sync["workstream_merge_order"], ["main", "dev"])
        self.assertEqual(sync["integration_dev_merges"], ["main"])
        self.assertEqual(sync["canonical_main_dev_action"], "fetch_and_inspect_only")
        self.assertIs(sync["require_clean_worktree"], True)
        self.assertIs(sync["stop_on_conflicts"], True)
        self.assertIs(sync["forbid_force"], True)
        self.assertIn("origin/dev_sha", sync["evidence"])
        self.assertIn("origin/main_sha", sync["evidence"])
        self.assertIn("utc_timestamp", sync["evidence"])
        self.assertIn("test_results", sync["evidence"])


if __name__ == "__main__":
    unittest.main()
