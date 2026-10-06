"""Path regression tests for manual QA; never launch or manipulate windows."""
import pathlib
import tempfile
import unittest
from persistence_acceptance import isolated_world_path


class IsolatedSaveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = pathlib.Path(self.temp.name) / 'run'
        self.directory.mkdir()
        self.reef = self.directory / 'reef.world'
        self.reef.write_bytes(b'fixture')

    def test_current_v3_path_stat_works_without_legacy_file(self):
        path = isolated_world_path({'path': str(self.reef)}, self.directory)
        self.assertEqual(path.stat().st_size, 7)
        self.assertFalse((self.directory / 'stream.world').exists())

    def test_legacy_path_rejected(self):
        path = self.directory / 'stream.world'
        path.write_bytes(b'legacy')
        with self.assertRaises(ValueError):
            isolated_world_path({'path': str(path)}, self.directory)

    def test_real_save_outside_run_rejected(self):
        path = pathlib.Path(self.temp.name) / 'reef.world'
        path.write_bytes(b'real')
        with self.assertRaises(ValueError):
            isolated_world_path({'path': str(path)}, self.directory)

    def test_symlink_outside_run_rejected(self):
        path = pathlib.Path(self.temp.name) / 'reef.world'
        path.write_bytes(b'real')
        self.reef.unlink()
        self.reef.symlink_to(path)
        with self.assertRaises(ValueError):
            isolated_world_path({'path': str(self.reef)}, self.directory)

    def test_missing_primary_file_rejected(self):
        self.reef.unlink()
        with self.assertRaises(FileNotFoundError):
            isolated_world_path({'path': str(self.reef)}, self.directory)


if __name__ == '__main__':
    unittest.main()
