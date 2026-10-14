"""Small, bounded filesystem and subprocess primitives used by both interfaces."""
import hashlib
import json
import os
import sys
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import zipfile

FROZEN = bool(getattr(sys, 'frozen', False))
ROOT = Path(sys._MEIPASS)/'payload' if FROZEN else Path(__file__).resolve().parents[1]


def user_workspace():
    if os.environ.get('CROC_WORKSPACE'):
        return Path(os.environ['CROC_WORKSPACE']).expanduser().resolve()
    if not FROZEN:
        return ROOT
    if sys.platform == 'win32':
        base = Path(os.environ.get('LOCALAPPDATA', Path.home()/'AppData/Local'))
    elif sys.platform == 'darwin':
        base = Path.home()/'Library/Application Support'
    else:
        base = Path(os.environ.get('XDG_DATA_HOME', Path.home()/'.local/share'))
    return base/'croc-of-slop-vr'


WORKSPACE = user_workspace()


def worker_command(*arguments):
    if FROZEN:
        return [sys.executable, '--worker', *map(str, arguments)]
    return [sys.executable, '-u', str(ROOT/'croc_builder.py'), *map(str, arguments)]


def python_command(script, *arguments):
    if FROZEN:
        return [sys.executable, '--python-script', str(script), *map(str, arguments)]
    return [sys.executable, str(script), *map(str, arguments)]


def external_environment():
    env = os.environ.copy()
    if FROZEN:
        for name in ('LD_LIBRARY_PATH', 'LIBPATH'):
            if name + '_ORIG' in env:
                env[name] = env[name + '_ORIG']
            else:
                env.pop(name, None)
    return env
LIMIT = 1_000_000_000  # Strictly less than one decimal GB, not one GiB.


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)


def contained(root, name):
    """Reject traversal, absolute paths, drives, symlinks and platform tricks."""
    if not isinstance(name, str) or '\\' in name or ':' in name or '\0' in name:
        raise ValueError('Unsafe relative path: ' + repr(name))
    parts = PurePosixPath(name)
    if parts.is_absolute() or '..' in parts.parts:
        raise ValueError('Unsafe relative path: ' + name)
    path = Path(root).joinpath(*parts.parts)
    if not path.resolve().is_relative_to(Path(root).resolve()):
        raise ValueError('Path escaped its destination: ' + name)
    return path


def unpack(archive, destination):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as source:
            for item in source.infolist():
                path = contained(destination, item.filename)
                if (item.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError('Archive contains a symbolic link')
                if item.is_dir():
                    path.mkdir(parents=True, exist_ok=True)
                else:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    with source.open(item) as src, path.open('wb') as dst:
                        import shutil
                        shutil.copyfileobj(src, dst)
                    mode = (item.external_attr >> 16) & 0o777
                    if mode:
                        path.chmod(mode)
    else:
        with tarfile.open(archive) as source:
            # Python 3.10 compatibility; extract members ourselves, never links.
            for item in source:
                path = contained(destination, item.name)
                if item.isdir():
                    path.mkdir(parents=True, exist_ok=True)
                elif item.isfile():
                    path.parent.mkdir(parents=True, exist_ok=True)
                    with source.extractfile(item) as src, path.open('wb') as dst:
                        import shutil
                        shutil.copyfileobj(src, dst)
                    path.chmod(item.mode & 0o777)
                else:
                    raise ValueError('Archive contains a link or special file')


class Runner:
    def __init__(self, log=print):
        self.log = log

    def run(self, args, cwd=None, env=None, godot=False):
        self.log('Running ' + Path(str(args[0])).name + ' ' + ' '.join(map(str, args[1:4])))
        options = {'creationflags': subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {}
        errors = []
        with subprocess.Popen(list(map(str, args)), cwd=cwd, env=env, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, encoding='utf-8',
                              errors='replace', **options) as process:
            for line in process.stdout:
                self.log(line.rstrip())
                if godot and line.startswith(('SCRIPT ERROR:', 'ERROR:')):
                    errors.append(line.rstrip())
            status = process.wait()
        if status or errors:
            raise RuntimeError(f'{Path(str(args[0])).name} failed ({status}). ' + '\n'.join(errors[-4:]))


def require_small(path):
    size = Path(path).stat().st_size
    if size <= 0 or size >= LIMIT:
        raise RuntimeError(f'{Path(path).name}: {size:,} bytes; output must be smaller than {LIMIT:,} bytes.')
    return size
