"""The catalog checker must also fail when things drift (a checker that cannot fail proves nothing)."""
import copy, hashlib, json, pathlib, sys, tempfile, unittest
from unittest import mock

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import check_physical_catalog as cc  # noqa: E402
import physical_schema as ps  # noqa: E402


class Base(unittest.TestCase):
    def setUp(self):
        self.mapping = json.loads(cc.MAPPING.read_text())
        self.erd = json.loads((cc.ROOT / self.mapping["erd"]).read_text())
        self.physical = ps.physical_tables()
        self.logical = ps.logical_entities(self.erd)

    def errors(self, mapping=None, physical=None, logical=None):
        return cc.check(mapping or self.mapping, self.erd, physical or self.physical, logical or self.logical)


class RealRepository(Base):
    def test_clean(self):
        self.assertEqual(self.errors(), [])

    def test_report_in_sync(self):
        self.assertEqual(cc.REPORT.read_text(), cc.render(self.mapping, self.erd, self.physical, self.logical))

    def test_every_m1_table_accounted_for(self):
        names = {t["physical"] for t in self.mapping["tables"]} | {w["physical"] for w in self.mapping["physical_without_entity"]}
        self.assertEqual(names, set(self.physical))


class DriftIsCaught(Base):
    def test_new_unmapped_table(self):
        p = copy.deepcopy(self.physical); p["new_table"] = {"id"}
        self.assertTrue(any("new_table" in e and "not in the mapping" in e for e in self.errors(physical=p)))

    def test_new_column_on_mapped_table(self):
        p = copy.deepcopy(self.physical); p["children"].add("birth_date")
        self.assertTrue(any("children" in e and "physical-only" in e for e in self.errors(physical=p)))

    def test_dropped_column(self):
        p = copy.deepcopy(self.physical); p["pairing_codes"].discard("attempt_count")
        self.assertTrue(any("pairing_codes" in e for e in self.errors(physical=p)))

    def test_erd_column_added(self):
        l = copy.deepcopy(self.logical); l["families"].add("extra")
        self.assertTrue(any("families" in e and "ERD-only" in e for e in self.errors(logical=l)))

    def test_erd_entity_removed(self):
        l = copy.deepcopy(self.logical); del l["children"]
        self.assertTrue(any("children" in e and "does not exist" in e for e in self.errors(logical=l)))

    def test_bad_rename_source_and_target(self):
        m = copy.deepcopy(self.mapping)
        next(t for t in m["tables"] if t["physical"] == "families")["column_renames"] = {"nope": "status"}
        self.assertTrue(any("rename source nope" in e for e in self.errors(mapping=m)))
        m = copy.deepcopy(self.mapping)
        next(t for t in m["tables"] if t["physical"] == "families")["column_renames"] = {"state": "nope"}
        self.assertTrue(any("rename target nope" in e for e in self.errors(mapping=m)))

    def test_entity_mapped_twice(self):
        m = copy.deepcopy(self.mapping)
        next(t for t in m["tables"] if t["physical"] == "devices")["logical"] = "children"
        self.assertTrue(any("already mapped" in e for e in self.errors(mapping=m)))

    def test_missing_note(self):
        m = copy.deepcopy(self.mapping); m["tables"][0]["note"] = " "
        self.assertTrue(any("note" in e for e in self.errors(mapping=m)))

    def test_mapping_names_table_no_migration_creates(self):
        m = copy.deepcopy(self.mapping); m["tables"].append({**m["tables"][0], "physical": "ghost"})
        self.assertTrue(any("ghost" in e for e in self.errors(mapping=m)))

    def test_entity_count_change(self):
        e = copy.deepcopy(self.erd); e["tableCount"] = 121
        self.assertTrue(any("tableCount" in x for x in cc.check(self.mapping, e, self.physical, self.logical)))

    def test_stale_report(self):
        text = cc.render(self.mapping, self.erd, self.physical, self.logical)
        m = copy.deepcopy(self.mapping); m["tables"][0]["note"] += " changed"
        self.assertNotEqual(text, cc.render(m, self.erd, self.physical, self.logical))


class Parser(unittest.TestCase):
    def test_duplicate_create_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'duplicate CREATE TABLE'):
            self.parse('CREATE TABLE ap_m1.a(id int); CREATE TABLE ap_m1.a(other int);')

    def parse(self, sql):
        with tempfile.TemporaryDirectory() as d:
            pathlib.Path(d, "0001_x.sql").write_text(sql)
            return ps.physical_tables(d)

    def test_columns_constraints_comments_and_alter(self):
        t = self.parse("""
          CREATE TABLE ap_m1.a (
            id uuid PRIMARY KEY, -- comment, with comma
            n numeric(10,2) NOT NULL,
            expires_at timestamptz,
            CHECK(expires_at > now()),
            UNIQUE(id, n),
            CONSTRAINT c CHECK (n > 0)
          );
          ALTER TABLE ap_m1.a ADD COLUMN extra text, ADD COLUMN IF NOT EXISTS more int;
          CREATE TABLE ap_m1.gone (id int);
          DROP TABLE ap_m1.gone;
        """)
        self.assertEqual(t, {"a": {"id", "n", "expires_at", "extra", "more"}})

    def test_erd_column_forms(self):
        erd = {"domains": [{"tables": [{"name": "x", "columns": [
            "PK FK device_id", "PK (a, b)", "FK c → y", "d, e : time", "f : enum?", "g, h optional", "invalidate cached child scopes"]}]}]}
        self.assertEqual(ps.logical_entities(erd)["x"], {"device_id", "a", "b", "c", "d", "e", "f", "g", "h"})


class ManifestSelection(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        self.migrations = self.root / 'backend/persistence/migrations'
        self.migrations.mkdir(parents=True)
        self.manifest = self.migrations.parent / 'migration-lineages.json'
        self.entries = []
        for n in range(1, 7):
            p = self.migrations / f'{n:04d}_m1.sql'
            sql = ('CREATE TABLE ap_m1.a(id int); CREATE TABLE other_schema.ignored(id int);'
                   if n == 1 else f'ALTER TABLE ap_m1.a ADD COLUMN c{n} int;')
            p.write_text(sql)
            self.entries.append({'id': 'common:0001' if n == 1 else f'm1:{n:04d}',
                                 'path': str(p.relative_to(self.root)),
                                 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()})
        # An alphabetical reader would consume this conflicting V2 CREATE.
        poison = self.migrations / '0002_v2.sql'
        poison.write_text('CREATE TABLE ap_m1.a(unwanted int);')
        self.entries.append({'id': 'v2:0002', 'path': str(poison.relative_to(self.root)),
                             'sha256': 'deliberately-invalid-unselected-checksum'})
        self.save()
        patcher = mock.patch.object(ps, 'MIGRATIONS', self.migrations)
        patcher.start()
        self.addCleanup(patcher.stop)

    def save(self):
        self.manifest.write_text(json.dumps({'migrations': list(reversed(self.entries))}))

    def parse(self, **kwargs):
        return ps.physical_tables(self.migrations, **kwargs)

    def test_current_checkpoint_selects_only_ordered_m1_through0006(self):
        self.assertEqual(self.parse(), {'a': {'id', 'c2', 'c3', 'c4', 'c5', 'c6'}})

    def test_frozen_checkpoint_selects_only_through0004(self):
        self.assertEqual(self.parse(checkpoint='0004'), {'a': {'id', 'c2', 'c3', 'c4'}})

    def test_selected_checksum_drift_is_rejected(self):
        (self.migrations / '0006_m1.sql').write_text('-- tampered')
        with self.assertRaisesRegex(ValueError, 'checksum drift: m1:0006'):
            self.parse()

    def test_missing_current_m1_entry_is_rejected(self):
        self.entries = [e for e in self.entries if e['id'] != 'm1:0006']
        self.save()
        with self.assertRaisesRegex(ValueError, 'manifest sequence'):
            self.parse()

    def test_duplicate_manifest_identity_is_rejected(self):
        self.entries.append(dict(self.entries[0]))
        self.save()
        with self.assertRaisesRegex(ValueError, 'manifest sequence'):
            self.parse()

    def test_unknown_future_m1_identity_is_rejected(self):
        self.entries.append({**self.entries[-2], 'id': 'm1:0007'})
        self.save()
        with self.assertRaisesRegex(ValueError, 'manifest sequence'):
            self.parse()

    def test_selected_path_outside_migrations_is_rejected(self):
        self.entries[0]['path'] = '../outside.sql'
        self.save()
        with self.assertRaisesRegex(ValueError, 'path outside migrations'):
            self.parse()

    def test_v2_and_unknown_checkpoint_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'only historical M1'):
            self.parse(lineage='v2')
        with self.assertRaisesRegex(ValueError, 'unsupported historical M1 checkpoint'):
            self.parse(checkpoint='0005')


class ERDNegativeControls(unittest.TestCase):
    def test_diagnostic_reports_actual_counts(self):
        from check_erd_references import validate
        errors = validate({'domains': [], 'domainCount': 2, 'tableCount': 3})
        self.assertIn('ERD tableCount 3 != 0 actual entities', errors)
        self.assertIn('ERD domainCount 2 != 0 actual domains', errors)

    def test_ascii_arrow_and_non_string_are_detected(self):
        from check_erd_references import validate
        errors = validate({'domainCount': 1, 'tableCount': 1, 'domains': [
            {'tables': [{'name': 'x', 'columns': ['FK y -> absent_entity', None]}]}]})
        self.assertTrue(any('absent_entity' in e and 'FK y -> absent_entity' in e for e in errors))
        self.assertIn('x: non-string column entry', errors)


if __name__ == "__main__":
    unittest.main()
