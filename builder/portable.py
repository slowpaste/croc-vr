"""Private, checksum-verified prerequisites for the downloadable desktop apps."""
import hashlib
import os
from pathlib import Path
import platform
import shutil
import ssl
import tarfile
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

from .common import WORKSPACE, contained, digest, read_json, write_json

NODE_VERSION = '22.23.0'
JAVA_TAG = 'jdk-17.0.20.1+1'
CACHE = WORKSPACE/'.cache/portable'
ANDROID_REPOSITORY = 'https://dl.google.com/android/repository/'
SDK_PACKAGES = ('platforms;android-36', 'build-tools;36.1.0', 'platform-tools', 'cmdline-tools;16.0')


def request(url):
    if not url.startswith('https://'):
        raise ValueError('Tool downloads require HTTPS')
    return urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'croc-of-slop-vr/1.1'}), timeout=120, context=tls_context())


def tls_context():
    # Frozen apps cannot rely on a separate Python installation's CA file.
    try:
        import certifi
    except ImportError:
        return ssl.create_default_context()
    context = ssl.create_default_context(cafile=certifi.where())
    context.load_default_certs()
    return context


def file_hash(path, algorithm='sha256'):
    h = hashlib.new(algorithm)
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def download(url, expected, destination, log, algorithm='sha256'):
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() and file_hash(destination, algorithm) == expected:
        return destination
    log('Downloading ' + destination.name)
    temporary = destination.with_name(destination.name + '.part')
    with request(url) as source, temporary.open('wb') as output:
        total = int(source.headers.get('Content-Length', 0))
        done, last = 0, -1
        while True:
            block = source.read(1024*1024)
            if not block:
                break
            output.write(block)
            done += len(block)
            percent = int(done*100/total) if total else 0
            if percent//10 != last:
                last = percent//10
                log(f'Downloading {destination.name}: {done//(1024*1024)} MB' + (f' / {total//(1024*1024)} MB' if total else ''))
    if file_hash(temporary, algorithm) != expected:
        raise RuntimeError('Download checksum mismatch: ' + destination.name + '. Retry to download it again.')
    temporary.replace(destination)
    return destination


def unpack_tool(archive, destination):
    """Verified vendor tools may have internal links; never allow links outside."""
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    links = []
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as source:
            for item in source.infolist():
                path = contained(destination, item.filename)
                mode = (item.external_attr >> 16)
                if mode & 0o170000 == 0o120000:
                    links.append((path, source.read(item).decode(), False))
                elif item.is_dir():
                    path.mkdir(parents=True, exist_ok=True)
                else:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    with source.open(item) as src, path.open('wb') as dst:
                        shutil.copyfileobj(src, dst)
                    if mode & 0o777:
                        path.chmod(mode & 0o777)
    else:
        with tarfile.open(archive) as source:
            for item in source:
                path = contained(destination, item.name)
                if item.issym() or item.islnk():
                    links.append((path, item.linkname, item.islnk()))
                elif item.isdir():
                    path.mkdir(parents=True, exist_ok=True)
                elif item.isfile():
                    path.parent.mkdir(parents=True, exist_ok=True)
                    with source.extractfile(item) as src, path.open('wb') as dst:
                        shutil.copyfileobj(src, dst)
                    path.chmod(item.mode & 0o777)
                else:
                    raise ValueError('Tool archive contains a special file')
    for path, target, hard in links:
        if Path(target).is_absolute() or ':' in target or '\\' in target:
            raise ValueError('Unsafe tool link')
        resolved = (destination/target if hard else path.parent/target).resolve()
        if not resolved.is_relative_to(destination.resolve()):
            raise ValueError('Tool link escaped its destination')
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.is_symlink():
            path.unlink()
        if hard:
            os.link(resolved, path)
        else:
            path.symlink_to(target, target_is_directory=resolved.is_dir())
        # A later link must not turn an earlier internal link into an escape.
        for created, _, _ in links:
            if created.is_symlink() and not created.resolve().is_relative_to(destination.resolve()):
                raise ValueError('Tool link chain escaped its destination')


def extracted(archive, directory):
    directory = Path(directory)
    identity = digest(archive)
    marker = directory/'.archive-sha256'
    if not marker.exists() or marker.read_text() != identity:
        unpack_tool(archive, directory)
        marker.write_text(identity)
    return directory


def host():
    system = {'Windows': 'win', 'Darwin': 'darwin', 'Linux': 'linux'}.get(platform.system())
    arch = {'AMD64': 'x64', 'x86_64': 'x64', 'aarch64': 'arm64', 'arm64': 'arm64'}.get(platform.machine())
    if not system or not arch or (system == 'win' and arch != 'x64'):
        raise RuntimeError('Use the desktop download matching your computer. Windows builds support x64.')
    return system, arch


def android_supported():
    system, arch = host()
    return not (system == 'linux' and arch == 'arm64')


def node(log=print):
    system, arch = host()
    suffix = '.zip' if system == 'win' else '.tar.gz'
    name = f'node-v{NODE_VERSION}-{system}-{arch}'
    base = f'https://nodejs.org/dist/v{NODE_VERSION}/'
    with request(base + 'SHASUMS256.txt') as response:
        sums = dict((line.split()[1], line.split()[0]) for line in response.read().decode().splitlines())
    archive = download(base + name + suffix, sums[name + suffix], CACHE/(name + suffix), log)
    directory = extracted(archive, CACHE/name)
    executable = directory/name/('node.exe' if system == 'win' else 'bin/node')
    if os.name != 'nt':
        executable.chmod(0o755)
    return executable


def java(log=print):
    from .toolchain import download_asset
    system, arch = host()
    name = f'OpenJDK17U-jdk_{"aarch64" if arch == "arm64" else "x64"}_{ {"win":"windows","linux":"linux","darwin":"mac"}[system]}_hotspot_17.0.20.1_1'
    suffix = '.zip' if system == 'win' else '.tar.gz'
    archive = download_asset('adoptium/temurin17-binaries', JAVA_TAG, name + suffix, CACHE/(name + suffix), log)
    directory = extracted(archive, CACHE/name)
    executable = next(directory.rglob('java.exe' if system == 'win' else 'java'))
    return executable.parent.parent


def sdk_manifest():
    with request(ANDROID_REPOSITORY + 'repository2-1.xml') as response:
        return ET.fromstring(response.read())


def sdk_selection(manifest, system=None):
    system = system or {'win':'windows', 'linux':'linux', 'darwin':'macosx'}[host()[0]]
    selected = []
    for package in SDK_PACKAGES:
        candidates = [p for p in manifest.findall('remotePackage') if p.get('path') == package]
        # Prefer the base API 36, not an extension platform with the same path.
        if package == 'platforms;android-36':
            candidates = [p for p in candidates if p.findtext('display-name') == 'Android SDK Platform 36']
        if len(candidates) != 1:
            raise RuntimeError('Google SDK metadata does not uniquely identify ' + package)
        p = candidates[0]
        archives = [a.find('complete') for a in p.findall('archives/archive') if a.findtext('host-os') in (None, system)]
        if len(archives) != 1:
            raise RuntimeError('No supported SDK download for ' + package)
        a = archives[0]
        relative = a.findtext('url')
        if not relative or '/' in relative or '\\' in relative or ':' in relative or '..' in relative:
            raise ValueError('Unsafe SDK URL')
        selected.append({'package':package, 'file':relative, 'sha1':a.findtext('checksum'), 'license':p.find('uses-license').get('ref')})
    return selected


def sdk_licenses(manifest=None):
    manifest = manifest if manifest is not None else sdk_manifest()
    needed = {p['license'] for p in sdk_selection(manifest)}
    return {p.get('id'): ''.join(p.itertext()) for p in manifest.findall('license') if p.get('id') in needed}


def consent_file():
    return CACHE/'android-consent.json'


def record_consent(licenses):
    """Called only by the user's Accept action, never automatically by setup."""
    from datetime import datetime, timezone
    write_json(consent_file(), {'acceptedAt':datetime.now(timezone.utc).isoformat(),
        'licenses':{key:hashlib.sha256(value.encode()).hexdigest() for key,value in licenses.items()}})


def needs_consent(licenses):
    accepted = read_json(consent_file()).get('licenses', {}) if consent_file().exists() else {}
    return any(accepted.get(key) != hashlib.sha256(value.encode()).hexdigest() for key,value in licenses.items())


def android_sdk(log=print):
    if not android_supported():
        raise RuntimeError('Android builds require Windows, macOS, or x64 Linux. This Linux ARM app can build for Frame.')
    manifest = sdk_manifest()
    licenses = sdk_licenses(manifest)
    if not licenses or needs_consent(licenses):
        raise RuntimeError('Review and accept the Android SDK terms in the app before building for Android.')
    sdk = CACHE/'android-sdk'
    for item in sdk_selection(manifest):
        archive = download(ANDROID_REPOSITORY + item['file'], item['sha1'], CACHE/item['file'], log, 'sha1')
        staging = extracted(archive, CACHE/('unpacked-' + item['file'].removesuffix('.zip')))
        destination = sdk.joinpath(*item['package'].replace('cmdline-tools;16.0', 'cmdline-tools;latest').split(';'))
        marker = destination/'.download-sha1'
        if not marker.exists() or marker.read_text() != item['sha1']:
            roots = [p for p in staging.iterdir() if p.is_dir()]
            if len(roots) != 1:
                raise RuntimeError('Unexpected SDK archive layout: ' + item['file'])
            shutil.copytree(roots[0], destination, dirs_exist_ok=True)
            marker.write_text(item['sha1'])
    (sdk/'licenses').mkdir(parents=True, exist_ok=True)
    for key, terms in licenses.items():
        # Google's License.getLicenseHash hashes exact UTF-8, including newlines.
        (sdk/'licenses'/key).write_text(hashlib.sha1(terms.encode()).hexdigest() + '\n')
    return sdk


def prepare(target, log=print, node_path=None):
    from .toolchain import CACHE as GODOT_CACHE, setup
    config_file = GODOT_CACHE/'paths.json'
    config = read_json(config_file) if config_file.exists() else {}
    if not all(Path(config.get(key, '__missing__')).exists() for key in ('godot', 'templates', 'vendors')):
        log('Setting up the game tools. Future builds reuse these files.')
        config = setup(log)
    config['node'] = str(node_path or node(log))
    try:
        import imageio_ffmpeg
        config['ffmpeg'] = imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        config['ffmpeg'] = shutil.which('ffmpeg')
    if not config.get('ffmpeg'):
        raise RuntimeError('This app is missing its bundled video tool. Download the release again.')
    if target in ('quest', 'both'):
        config['java'] = str(java(log))
        config['sdk'] = str(android_sdk(log))
    write_json(config_file, config)
    return config
