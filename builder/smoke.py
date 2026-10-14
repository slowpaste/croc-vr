"""Exercise the real frozen UI, worker dispatch and packer without game content."""
import json
import os
from pathlib import Path
import subprocess
import tempfile


def verify():
    from .common import ROOT, WORKSPACE, external_environment, python_command, worker_command
    from .desktop import DesktopWindow
    import tkinter as tk
    import imageio_ffmpeg
    checks = []
    from .portable import tls_context
    import certifi
    assert Path(certifi.where()).is_file()
    assert tls_context().cert_store_stats()['x509_ca'] > 0
    checks.append('HTTPS root certificates included without external Python')
    root = tk.Tk()
    root.withdraw()
    window = DesktopWindow(root)
    root.update()
    assert root.title() == 'croc of slop VR'
    assert len(window.buttons) == 2
    root.destroy()
    checks.append('real Tk desktop initialized with two headset buttons')
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    options = {'creationflags':subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {}
    result = subprocess.run([ffmpeg, '-encoders'], capture_output=True, text=True, env=external_environment(), timeout=30, **options)
    assert result.returncode == 0 and 'libtheora' in result.stdout and 'libvorbis' in result.stdout, result.stderr
    checks.append('bundled FFmpeg runs and includes Theora/Vorbis encoders')
    with tempfile.TemporaryDirectory(prefix='croc frozen smoke ') as folder:
        directory = Path(folder)
        content = directory/'content'
        content.mkdir()
        (content/'a.json').write_text('{"test":true}')
        (content/'b.json').write_text('{"test":true}')
        plan = directory/'plan.json'
        plan.write_text(json.dumps({'root':str(content), 'files':[{'file':name, 'bytes':13} for name in ('a.json','b.json')], 'bytes':26}))
        result = subprocess.run(python_command(ROOT/'engine/tools/package-quest-bundled-content.py', plan, directory/'bundle'), capture_output=True, text=True, timeout=60, **options)
        index_path = directory/'bundle/index.json'
        assert result.returncode == 0 and index_path.exists(), result.stderr
        index = json.loads(index_path.read_text())
        assert index['files'] == 2 and index['uniquePayloads'] == 1
        checks.append('frozen Python worker creates deduplicated PCK and ZIP assets')
        result = subprocess.run(worker_command('--version'), capture_output=True, text=True, timeout=30, **options)
        assert result.returncode == 0
        checks.append('internal CLI worker exits successfully')
    assert (ROOT/'engine/game/project.godot').is_file()
    assert (ROOT/'engine/tools/check-disc.cjs').is_file()
    assert (ROOT/'scripts/verify-frame-data.gd').is_file()
    checks.append('native runtime, importer and integrity-check source included')
    return {'ok':True, 'checks':checks, 'workspace':str(WORKSPACE)}
