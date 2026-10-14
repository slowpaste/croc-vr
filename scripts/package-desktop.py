"""Build a native release on its own OS. Only Git-tracked source is included."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from builder import __version__


def run(*arguments):
    subprocess.run(list(map(str, arguments)), check=True, cwd=ROOT)


def package():
    parser = argparse.ArgumentParser()
    parser.add_argument('--smoke', action='store_true')
    args = parser.parse_args()
    system = platform.system()
    arch = 'arm64' if platform.machine().lower() in ('arm64','aarch64') else 'x64'
    build = ROOT/'build/desktop'
    payload = build/('payload-' + uuid.uuid4().hex[:8])
    payload.mkdir(parents=True, exist_ok=True)
    tracked = subprocess.check_output(['git','ls-files','-z'], cwd=ROOT).decode().split('\0')
    for name in tracked:
        if not name or not (name.startswith(('builder/','engine/','scripts/','docs/')) or name in ('LICENSE','THIRD_PARTY.md','README.md','croc_builder.py','desktop_entry.py')):
            continue
        source = ROOT/name
        if source.is_symlink() or not source.is_file():
            raise RuntimeError('Missing or linked source: ' + name)
        destination = payload/name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    if not (payload/'builder/app.py').exists():
        raise RuntimeError('Stage the desktop source in Git before packaging it.')
    command = [sys.executable,'-m','PyInstaller','--noconfirm','--clean','--noupx',
        '--name','croc-of-slop-vr','--distpath',str(build/'dist'),'--workpath',str(build/'work'),
        '--specpath',str(build),'--add-data',str(payload)+':payload',
        '--collect-all','imageio_ffmpeg','--collect-all','certifi','--collect-submodules','builder',
        '--hidden-import','concurrent.futures.thread','--hidden-import','tkinter',
        '--hidden-import','tkinter.ttk','--hidden-import','tkinter.filedialog',
        '--hidden-import','tkinter.messagebox']
    command += ['--onedir','--windowed','--osx-bundle-identifier','io.github.slowpaste.croc-of-slop-vr'] if system == 'Darwin' else ['--onefile']
    if system == 'Windows':
        command.append('--windowed')
    command.append(str(ROOT/'desktop_entry.py'))
    run(*command)
    if system == 'Windows':
        executable = build/'dist/croc-of-slop-vr.exe'
    elif system == 'Darwin':
        executable = build/'dist/croc-of-slop-vr.app/Contents/MacOS/croc-of-slop-vr'
    else:
        executable = build/'dist/croc-of-slop-vr'
    if args.smoke:
        report = build/'smoke.json'
        report.unlink(missing_ok=True)
        subprocess.run([str(executable),'--smoke-test',str(report)], check=True, timeout=180)
        if not report.exists() or not json.loads(report.read_text()).get('ok'):
            raise RuntimeError('Packaged-app smoke test failed')
        print(report.read_text(), flush=True)
    release = ROOT/'dist/desktop-release'
    release.mkdir(parents=True, exist_ok=True)
    stem = f'croc-of-slop-vr-{ {"Windows":"windows","Darwin":"macos","Linux":"linux"}[system]}-{arch}'
    if system == 'Windows':
        artifact = release/(stem + '.exe')
        shutil.copy2(executable, artifact)
    elif system == 'Darwin':
        artifact = release/(stem + '.dmg')
        image = build/'dmg'
        image.mkdir(exist_ok=True)
        destination = image/'croc of slop VR.app'
        shutil.copytree(build/'dist/croc-of-slop-vr.app', destination, dirs_exist_ok=True, symlinks=True)
        application_link = image/'Applications'
        if not application_link.exists():
            application_link.symlink_to('/Applications', target_is_directory=True)
        run('hdiutil','create','-volname','croc of slop VR','-srcfolder',image,'-ov','-format','UDZO',artifact)
    else:
        artifact = release/(stem + '.tar.gz')
        with tarfile.open(artifact,'w:gz') as archive:
            archive.add(executable, arcname='croc-of-slop-vr')
            archive.add(ROOT/'LICENSE', arcname='LICENSE')
    checksum = hashlib.sha256(artifact.read_bytes()).hexdigest()
    (release/(artifact.name + '.sha256')).write_text(checksum + '  ' + artifact.name + '\n')
    print(f'RELEASE_READY {artifact} ({artifact.stat().st_size:,} bytes)', flush=True)


if __name__ == '__main__':
    package()
