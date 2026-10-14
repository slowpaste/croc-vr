"""Pinned, hash-verified Godot and OpenXR vendor downloads. No global installs."""
import os
from pathlib import Path
import platform
import shutil
import urllib.request

from .common import ROOT, WORKSPACE, digest, read_json, write_json
from .portable import unpack_tool, download, request as tool_request

GODOT = '4.7.2-stable'
VENDORS = '5.1.0-stable'
CACHE = WORKSPACE / '.cache/toolchain'


def fetch_json(url):
    with tool_request(url) as response:
        import json
        return json.load(response)


def download_asset(repo, tag, name, destination, log):
    # Digests are captured from official release metadata when pins are updated.
    # Setup needs no GitHub account, API token, or remaining API quota.
    lock = read_json(ROOT/'builder/tool-lock.json')
    asset = lock['assets'].get('/'.join((repo, tag, name)))
    if not asset:
        raise RuntimeError('This app has no verified download for ' + name + '. Download the current release.')
    return download(asset['url'], asset['sha256'], destination, log)


def setup(log=print):
    machine = platform.machine().lower()
    system = platform.system()
    if system == 'Windows' and machine in ('amd64', 'x86_64'):
        suffix = 'win64.exe.zip'
    elif system == 'Linux' and machine in ('amd64', 'x86_64', 'aarch64', 'arm64'):
        suffix = 'linux.' + ('arm64' if machine in ('aarch64', 'arm64') else 'x86_64') + '.zip'
    elif system == 'Darwin':
        suffix = 'macos.universal.zip'
    else:
        raise RuntimeError('Set --godot to a Godot 4.7.2 editor for this host.')
    editor_name = f'Godot_v{GODOT}_{suffix}'
    editor_archive = download_asset('godotengine/godot-builds', GODOT, editor_name, CACHE/editor_name, log)
    template_name = f'Godot_v{GODOT}_export_templates.tpz'
    template_archive = download_asset('godotengine/godot-builds', GODOT, template_name, CACHE/template_name, log)
    vendors_archive = download_asset('GodotVR/godot_openxr_vendors', VENDORS, 'godotopenxrvendorsaddon.zip', CACHE/'vendors.zip', log)
    for archive, directory in ((editor_archive, CACHE/'editor'), (template_archive, CACHE/'templates'), (vendors_archive, CACHE/'vendors')):
        marker = directory / '.archive-sha256'
        identity = digest(archive)
        if not marker.exists() or marker.read_text() != identity:
            unpack_tool(archive, directory)
            marker.write_text(identity)
    if system == 'Darwin':
        editor = CACHE/'editor/Godot.app/Contents/MacOS/Godot'
    elif system == 'Windows':
        editor = next(p for p in (CACHE/'editor').glob('*.exe') if not p.name.endswith('_console.exe'))
    else:
        editor = next(p for p in (CACHE/'editor').iterdir() if p.name.startswith('Godot_v'))
    if os.name != 'nt':
        editor.chmod(0o755)
    vendors = next((CACHE/'vendors').rglob('godotopenxrvendors'))
    config = {'godot': str(editor.resolve()), 'templates': str((CACHE/'templates/templates').resolve()), 'vendors': str(vendors.parent.resolve())}
    write_json(CACHE/'paths.json', config)
    log('Game tools are ready. Android builds also need Java 17 and the Android SDK; see docs/setup.md.')
    return config


def paths(args):
    config = read_json(CACHE/'paths.json') if (CACHE/'paths.json').exists() else {}
    result = {}
    for key in ('godot', 'templates', 'vendors', 'sdk', 'java', 'ffmpeg', 'node'):
        value = getattr(args, key, None) or os.environ.get('CROC_' + key.upper()) or config.get(key)
        if key == 'sdk':
            value = value or os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
        if key == 'java':
            value = value or os.environ.get('JAVA_HOME')
        if key == 'ffmpeg':
            value = value or shutil.which('ffmpeg')
        if value:
            resolved = shutil.which(str(value)) if key in ('godot', 'ffmpeg') else None
            result[key] = Path(resolved or value).expanduser().resolve()
            if key == 'godot' and os.name == 'nt' and result[key].name.endswith('_console.exe'):
                direct = result[key].with_name(result[key].name.replace('_console.exe', '.exe'))
                if direct.exists():
                    result[key] = direct
    for key in ('godot', 'templates', 'ffmpeg'):
        if key not in result or not result[key].exists():
            raise RuntimeError(f'Missing {key}. Run setup / see docs/setup.md, or supply --{key}.')
    if args.target in ('quest', 'both'):
        for key in ('vendors', 'sdk', 'java'):
            if key not in result or not result[key].exists():
                raise RuntimeError(f'Quest builds need --{key}; see docs/setup.md.')
    return result
