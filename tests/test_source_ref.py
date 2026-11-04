import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('resolve_source_ref', Path(__file__).resolve().parents[1] / 'scripts/resolve_source_ref.py')
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)


class SourceReferenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='release-source-test-')
        self.repo = Path(self.temp.name)
        self.git('init', '-q'); self.git('config', 'user.name', 'Release QA'); self.git('config', 'user.email', 'qa@example.test')
        self.git('-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '-qm', 'source-ref: not a release annotation')

    def tearDown(self): self.temp.cleanup()

    def git(self, *args): subprocess.run(['git', '-C', str(self.repo), *args], check=True, capture_output=True)

    def test_annotated_tag_pins_source_commit(self):
        sha = 'abcdef01' * 5
        self.git('-c', 'tag.gpgsign=false', 'tag', '-a', 'appbackend-v110407', '-m', 'source-ref: ' + sha)
        self.assertEqual(module.source_ref(self.repo, 'appbackend-v110407'), sha)

    def test_legacy_lightweight_tag_uses_default_branch(self):
        self.git('tag', 'legacy-v1')
        self.assertEqual(module.source_ref(self.repo, 'legacy-v1'), 'main')

    def test_legacy_annotation_without_source_ref_keeps_compatibility(self):
        self.git('-c', 'tag.gpgsign=false', 'tag', '-a', 'legacy-v1', '-m', 'Existing release')
        self.assertEqual(module.source_ref(self.repo, 'legacy-v1'), 'main')

    def test_bad_pin_cannot_silently_release_a_different_source(self):
        self.git('-c', 'tag.gpgsign=false', 'tag', '-a', 'broken-v1', '-m', 'source-ref: moving-branch')
        with self.assertRaises(ValueError): module.source_ref(self.repo, 'broken-v1')
