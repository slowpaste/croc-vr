import hashlib
import io
import os
from pathlib import Path
import tarfile
import tempfile
import unittest
import zipfile
from unittest.mock import patch
import xml.etree.ElementTree as ET

from builder import common, portable


def repository():
    root = ET.Element('sdk')
    ET.SubElement(root, 'license', id='android-sdk-license').text = '\nSynthetic test terms, not a real agreement.\n'
    for name in portable.SDK_PACKAGES:
        p = ET.SubElement(root, 'remotePackage', path=name)
        ET.SubElement(p, 'display-name').text = 'Android SDK Platform 36' if name.startswith('platforms;') else name
        ET.SubElement(p, 'uses-license', ref='android-sdk-license')
        complete = ET.SubElement(ET.SubElement(ET.SubElement(p, 'archives'), 'archive'), 'complete')
        ET.SubElement(complete, 'url').text = name.replace(';', '-') + '.zip'
        ET.SubElement(complete, 'checksum').text = 'a'*40
    return root


class PrivateSetup(unittest.TestCase):
    def test_sdk_archives_become_a_complete_private_sdk_with_exact_consent_hash(self):
        manifest = repository()
        layouts = {
            'platforms-android-36.zip':('android-36/android.jar','platforms/android-36/android.jar'),
            'build-tools-36.1.0.zip':('android-36.1/aapt2','build-tools/36.1.0/aapt2'),
            'platform-tools.zip':('platform-tools/adb','platform-tools/adb'),
            'cmdline-tools-16.0.zip':('cmdline-tools/bin/sdkmanager','cmdline-tools/latest/bin/sdkmanager'),
        }
        def fixture_download(url, expected, destination, log, algorithm):
            destination.parent.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(destination, 'w') as archive:
                archive.writestr(layouts[destination.name][0], b'fixture tool')
            return destination
        with tempfile.TemporaryDirectory() as folder, patch.object(portable, 'CACHE', Path(folder)), patch.object(portable, 'sdk_manifest', return_value=manifest), patch.object(portable, 'android_supported', return_value=True), patch.object(portable, 'host', return_value=('win','x64')), patch.object(portable, 'download', side_effect=fixture_download):
            terms = portable.sdk_licenses(manifest)
            portable.record_consent(terms)  # Synthetic fixture only.
            sdk = portable.android_sdk()
            self.assertTrue(sdk.is_relative_to(Path(folder)))
            for _, destination in layouts.values():
                self.assertEqual((sdk/destination).read_bytes(), b'fixture tool')
            self.assertEqual((sdk/'licenses/android-sdk-license').read_text().strip(), hashlib.sha1(terms['android-sdk-license'].encode()).hexdigest())

    def test_vendor_internal_links_work_but_escape_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            for target, accepted in [('jdk/lib/real', True), ('../../outside', False)]:
                archive = directory/'tool.tar'
                with tarfile.open(archive, 'w') as out:
                    entry = tarfile.TarInfo('jdk/lib/real')
                    entry.size = 4
                    out.addfile(entry, io.BytesIO(b'tool'))
                    link = tarfile.TarInfo('jdk/lib/link')
                    link.type = tarfile.LNKTYPE
                    link.linkname = target
                    out.addfile(link)
                destination = directory/str(accepted)
                if accepted:
                    portable.unpack_tool(archive, destination)
                    self.assertEqual((destination/'jdk/lib/link').read_bytes(), b'tool')
                else:
                    with self.assertRaisesRegex(ValueError, 'escaped'):
                        portable.unpack_tool(archive, destination)

    def test_android_downloads_require_consent_to_the_exact_current_terms(self):
        manifest = repository()
        with tempfile.TemporaryDirectory() as folder, patch.object(portable, 'CACHE', Path(folder)), patch.object(portable, 'sdk_manifest', return_value=manifest), patch.object(portable, 'android_supported', return_value=True), patch.object(portable, 'host', return_value=('win','x64')), patch.object(portable, 'download') as download:
            with self.assertRaisesRegex(RuntimeError, 'Review and accept'):
                portable.android_sdk()
            download.assert_not_called()
            terms = portable.sdk_licenses(manifest)
            self.assertEqual(terms['android-sdk-license'], manifest.find('license').text)
            portable.record_consent(terms)  # Synthetic agreement fixture only.
            self.assertFalse(portable.needs_consent(terms))
            changed = dict(terms)
            changed['android-sdk-license'] += ' amended'
            self.assertTrue(portable.needs_consent(changed))

    def test_sdk_selects_base_platform_and_rejects_remote_url_injection(self):
        manifest = repository()
        extension = ET.SubElement(manifest, 'remotePackage', path='platforms;android-36')
        ET.SubElement(extension, 'display-name').text = 'Android SDK Platform 36-ext19'
        selected = portable.sdk_selection(manifest, 'windows')
        self.assertEqual(len(selected), 4)
        manifest.find('remotePackage/archives/archive/complete/url').text = '../escape.zip'
        with self.assertRaisesRegex(ValueError, 'Unsafe SDK URL'):
            portable.sdk_selection(manifest, 'windows')

    def test_modified_download_never_becomes_a_tool(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder)/'tool.zip'
            expected = hashlib.sha256(b'expected').hexdigest()
            response = io.BytesIO(b'tampered')
            response.headers = {}
            with patch.object(portable, 'request', return_value=response):
                with self.assertRaisesRegex(RuntimeError, 'checksum mismatch'):
                    portable.download('https://example.test/tool.zip', expected, destination, lambda line:None)
            self.assertFalse(destination.exists())

    def test_frozen_workers_use_the_app_and_not_an_installed_python(self):
        with patch.object(common, 'FROZEN', True):
            self.assertEqual(common.worker_command('build')[1:], ['--worker','build'])
            self.assertEqual(common.python_command('packer.py','plan.json')[1:], ['--python-script','packer.py','plan.json'])
        with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, {'CROC_WORKSPACE':folder}):
            self.assertEqual(common.user_workspace(), Path(folder).resolve())


if __name__ == '__main__':
    unittest.main()
