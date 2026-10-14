import hashlib
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tarfile
import tempfile
import unittest
import zipfile

from builder.cli import parser
from builder.common import LIMIT, ROOT, contained, digest, require_small, unpack
from builder.pipeline import android_editor_settings, export_presets, isolated_editor, make_plan


class PathSafety(unittest.TestCase):
    def test_archive_rejects_escape_and_links(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for bad in ('../escape', '/absolute', 'C:/drive', 'a\\..\\escape'):
                with self.assertRaises(ValueError):
                    contained(root, bad)
            archive = root/'attack.zip'
            with zipfile.ZipFile(archive, 'w') as out:
                out.writestr('../escape', 'no')
            with self.assertRaises(ValueError):
                unpack(archive, root/'unpacked')
            self.assertFalse((root/'escape').exists())
            archive = root/'link.tar'
            with tarfile.open(archive, 'w') as out:
                item = tarfile.TarInfo('link')
                item.type = tarfile.SYMTYPE
                item.linkname = '../../elsewhere'
                out.addfile(item)
            with self.assertRaises(ValueError):
                unpack(archive, root/'links')

    def test_size_limit_is_strict_decimal_gb(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory)/'app'
            file.write_bytes(b'ok')
            self.assertEqual(require_small(file), 2)
            # Sparse file exercises the real filesystem boundary without 1 GB of RAM.
            with file.open('wb') as output:
                output.truncate(LIMIT)
            with self.assertRaisesRegex(RuntimeError, 'smaller'):
                require_small(file)


class Packaging(unittest.TestCase):
    def test_android_settings_are_kept_in_a_private_portable_editor(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root/'original/godot'
            original.parent.mkdir()
            original.write_bytes(b'editor fixture')
            job = root/'job'
            job.mkdir()
            tools = isolated_editor({'godot':original, 'java':root/'jdk', 'sdk':root/'sdk'}, job)
            android_editor_settings(tools, root/'signing.keystore')
            self.assertTrue((job/'editor/_sc_').exists())
            self.assertEqual(tools['godot'].read_bytes(), original.read_bytes())
            self.assertFalse((original.parent/'_sc_').exists())
            settings = job/'editor/editor_data/editor_settings-4.7.tres'
            self.assertIn('export/android/java_sdk_path', settings.read_text())
            self.assertFalse((original.parent/'editor_data').exists())

    def test_deduplicated_pack_round_trip_and_zip_integrity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            content = root/'content'
            (content/'resources').mkdir(parents=True)
            payload = b'mesh' * 1000
            (content/'resources/a.res').write_bytes(payload)
            (content/'resources/b.res').write_bytes(payload)
            (content/'manifest.json').write_text('{"schema":1}')
            plan = root/'plan.json'
            make_plan(content, plan)
            out = root/'out'
            subprocess.run([sys.executable, ROOT/'engine/tools/package-quest-bundled-content.py', plan, out], check=True, capture_output=True)
            index = json.loads((out/'index.json').read_text())
            self.assertEqual(index['files'], 3)
            self.assertEqual(index['uniquePayloads'], 2)
            pack = index['packs'][0]
            self.assertEqual(digest(out/pack['file']), pack['sha256'])
            with zipfile.ZipFile(out/pack['archive']) as archive:
                self.assertIsNone(archive.testzip())
                self.assertEqual(archive.read(pack['file']), (out/pack['file']).read_bytes())
            with (out/pack['file']).open('rb') as stream:
                header = stream.read(96)
                magic, version, major, minor, patch, flags, base = struct.unpack('<IIIIIIQ', header[:32])
                self.assertEqual((magic, version, flags), (0x43504447, 2, 2))
                count = struct.unpack('<I', stream.read(4))[0]
                entries = {}
                for _ in range(count):
                    n = struct.unpack('<I', stream.read(4))[0]
                    name = stream.read(n).rstrip(b'\0').decode()
                    offset, size = struct.unpack('<QQ', stream.read(16))
                    md5 = stream.read(16)
                    stream.read(4)
                    entries[name] = (base + offset, size, md5)
                self.assertEqual(entries['imported_data/resources/a.res'], entries['imported_data/resources/b.res'])
                for name, (offset, size, md5) in entries.items():
                    stream.seek(offset)
                    data = stream.read(size)
                    self.assertEqual(hashlib.md5(data).digest(), md5)
                    self.assertEqual(data, (content/name.removeprefix('imported_data/')).read_bytes())

    def test_corrupted_source_mesh_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'mesh.res').write_bytes(b'wrong')
            plan = {'root': str(root), 'files': [{'file': 'mesh.res', 'bytes': 5, 'sha256': '0'*64}], 'bytes':5}
            (root/'plan.json').write_text(json.dumps(plan))
            result = subprocess.run([sys.executable, ROOT/'engine/tools/package-quest-bundled-content.py', root/'plan.json', root/'out'], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((root/'out/index.json').exists())

    def test_both_targets_include_data_and_native_arm64(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for target in ('frame', 'quest'):
                export_presets(root, {'templates': root}, target, '2026.10.14', 100)
                preset = (root/'export_presets.cfg').read_text()
                self.assertIn('bundled-content/*.zip', preset)
                self.assertIn('linux_release.arm64' if target == 'frame' else 'architectures/arm64-v8a=true', preset)
                if target == 'quest':
                    self.assertIn('enable_meta_plugin=true', preset)
                    self.assertIn('keystore/release=', preset)

    def test_generated_files_not_present_in_source(self):
        for path in (ROOT/'engine').rglob('*'):
            self.assertNotIn(path.suffix, ('.iso', '.bin', '.apk', '.pck', '.ogv', '.keystore'))


class Interface(unittest.TestCase):
    def test_cli_preserves_paths_with_spaces(self):
        args = parser().parse_args(['build', '--iso', '/my discs/Croc.bin', '--target', 'frame', '--local-source'])
        self.assertEqual(args.iso, '/my discs/Croc.bin')
        self.assertTrue(args.local_source)


if __name__ == '__main__':
    unittest.main()
