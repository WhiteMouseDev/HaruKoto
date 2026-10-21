"""Exercise the CI gate independently of database availability."""

import importlib.util
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check_postgres_junit.py"
SPEC = importlib.util.spec_from_file_location("check_postgres_junit", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
GUARD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GUARD)


class CheckPostgresJunitTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.report = Path(self.directory.name) / "results.xml"
        self.root = ET.Element("testsuites")
        self.suite = ET.SubElement(self.root, "testsuite")
        for classname, name in sorted(GUARD.REQUIRED_CASES):
            ET.SubElement(self.suite, "testcase", classname=classname, name=name)

    def write_report(self) -> None:
        ET.ElementTree(self.root).write(self.report, encoding="utf-8", xml_declaration=True)

    def test_all_required_cases_pass(self) -> None:
        self.write_report()
        self.assertEqual(len(GUARD.REQUIRED_CASES), 61)
        self.assertEqual(GUARD.check_report(self.report), [])

    def test_optional_ai_skips_are_allowed(self) -> None:
        for index in range(13):
            testcase = ET.SubElement(self.suite, "testcase", classname="tests.test_ai_live", name=f"test_optional_provider[{index}]")
            ET.SubElement(testcase, "skipped", message="Optional AI credentials not configured")
        self.write_report()
        self.assertEqual(GUARD.check_report(self.report), [])

    def test_each_required_case_must_be_present(self) -> None:
        for testcase in list(self.suite):
            with self.subTest(name=testcase.get("name")):
                self.suite.remove(testcase)
                self.write_report()
                errors = GUARD.check_report(self.report)
                self.assertEqual(len(errors), 1)
                self.assertIn(testcase.get("name"), errors[0])
                self.assertIn("found 0", errors[0])
                self.suite.append(testcase)

    def test_required_skip_failure_and_error_are_rejected(self) -> None:
        testcase = self.suite[0]
        for status in ("skipped", "failure", "error"):
            with self.subTest(status=status):
                result = ET.SubElement(testcase, status)
                self.write_report()
                errors = GUARD.check_report(self.report)
                self.assertEqual(len(errors), 1)
                self.assertIn(f"reported {status}", errors[0])
                testcase.remove(result)

    def test_duplicate_result_cannot_replace_missing_test(self) -> None:
        missing = self.suite[0]
        duplicate = self.suite[1]
        self.suite.remove(missing)
        ET.SubElement(self.suite, "testcase", **duplicate.attrib)
        self.write_report()
        errors = GUARD.check_report(self.report)
        self.assertEqual(len(errors), 2)
        self.assertTrue(any("found 0" in error for error in errors))
        self.assertTrue(any("found 2" in error for error in errors))

    def test_missing_report_is_rejected(self) -> None:
        self.assertIn("Cannot read pytest JUnit report", GUARD.check_report(self.report)[0])

    def test_malformed_report_is_rejected(self) -> None:
        self.report.write_text("<testsuites><", encoding="utf-8")
        self.assertIn("Cannot read pytest JUnit report", GUARD.check_report(self.report)[0])

    def test_empty_report_is_rejected(self) -> None:
        self.suite.clear()
        self.write_report()
        self.assertEqual(len(GUARD.check_report(self.report)), 61)

    def test_cli_returns_nonzero_when_a_regression_is_skipped(self) -> None:
        ET.SubElement(self.suite[0], "skipped")
        self.write_report()
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.report)], capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn("::error::", result.stdout)

    def test_cli_reports_success_for_all_required_cases(self) -> None:
        self.write_report()
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.report)], capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0)
        self.assertIn("All 61 required PostgreSQL regression cases passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
