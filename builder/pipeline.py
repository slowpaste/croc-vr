"""Import once, prepare compact VR content, export the same snapshot per headset."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

from .common import ROOT, WORKSPACE, Runner, python_command, external_environment, contained, digest, read_json, require_small, write_json
from . import __version__
from .instructions import installation_text
from .toolchain import paths


def source_identity():
    """Hash only runtime and importer source, including local edits."""
    import hashlib
    h = hashlib.sha256()
    for folder in ('builder', 'engine/game', 'engine/tools'):
        for file in sorted((ROOT/folder).rglob('*')):
            if file.is_file() and file.suffix in ('.py', '.cjs', '.json', '.gd', '.tscn', '.tres', '.gdshader', '.gdshaderinc', '.godot', '.png', '.svg'):
                if '.godot' in file.relative_to(ROOT/folder).parts:
                    continue
                h.update(file.relative_to(ROOT).as_posix().encode())
                h.update(bytes.fromhex(digest(file)))
    return h.hexdigest()


def update_source(log=print):
    options = {'creationflags': subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {}
    def git(*args):
        return subprocess.check_output(['git', '-C', str(ROOT), *args], text=True, stderr=subprocess.STDOUT, **options).strip()
    if git('rev-parse', '--show-toplevel').replace('\\', '/').lower() != str(ROOT).replace('\\', '/').lower():
        raise RuntimeError('This is a source archive. Clone the repository for automatic updates, or use --local-source.')
    if git('status', '--porcelain'):
        raise RuntimeError('Source has local edits. Commit them before updating, or select --local-source.')
    remote = git('remote', 'get-url', 'origin')
    if not re.fullmatch(r'(https://github.com/|git@github.com:)slowpaste/croc-vr(?:\.git)?', remote):
        raise RuntimeError('Automatic updates require the slowpaste/croc-vr origin. Use --local-source for a fork.')
    log('Checking the latest source on GitHub…')
    git('fetch', 'origin', 'main')
    if git('rev-parse', 'HEAD') != git('rev-parse', 'origin/main'):
        if git('branch', '--show-current') != 'main':
            raise RuntimeError('Switch to main or select --local-source to build this branch.')
        git('merge', '--ff-only', 'origin/main')
        log('Source updated. Restarting with the current builder.')
        return True
    log('Source is current: ' + git('rev-parse', '--short', 'HEAD'))
    return False


def make_plan(content, destination):
    """Inventory current import only; the slim planner removes duplicate formats."""
    records = []
    for file in sorted(content.rglob('*')):
        if file.is_symlink():
            raise RuntimeError('Imported content must not contain symlinks')
        if file.is_file() and file.name != 'LOCAL-CONTENT.txt':
            name = file.relative_to(content).as_posix()
            record = {'file': name, 'bytes': file.stat().st_size}
            # The compact planner excludes legacy sequence-pass meshes. Do not
            # reread those discarded files when recovering an older work folder.
            discarded_mesh = name.startswith('resources/sequence-') and '-portals-' not in name
            if (file.suffix == '.res' and not discarded_mesh) or name.startswith('raw/'):
                record['sha256'] = digest(file)
            records.append(record)
    write_json(destination, {'root': str(content), 'files': records, 'bytes': sum(r['bytes'] for r in records)})


def cfg_path(value):
    return json.dumps(str(value).replace('\\', '/'), ensure_ascii=False)


def isolated_editor(tools, job):
    """Use Godot's documented portable mode; never edit the user's settings."""
    tools = dict(tools)
    source = tools['godot']
    if os.name == 'nt' and source.name.endswith('_console.exe'):
        direct = source.with_name(source.name.replace('_console.exe', '.exe'))
        if not direct.exists():
            raise RuntimeError('Select the Godot editor .exe, not a console wrapper without its editor binary.')
        source = direct
    directory = job/'editor'
    directory.mkdir(exist_ok=True)
    if sys.platform == 'darwin' and any(p.suffix == '.app' for p in source.parents):
        app = next(p for p in source.parents if p.suffix == '.app')
        destination = directory/app.name
        if not destination.exists():
            shutil.copytree(app, destination, symlinks=True)
        executable = destination/source.relative_to(app)
    else:
        executable = directory/source.name
        if not executable.exists():
            shutil.copy2(source, executable)
    (executable.parent/'_sc_').touch()
    tools['godot'] = executable
    return tools


def android_editor_settings(tools, keystore):
    directory = tools['godot'].parent/'editor_data'
    directory.mkdir(exist_ok=True)
    settings = directory/'editor_settings-4.7.tres'
    values = {'export/android/java_sdk_path': str(tools['java']),
              'export/android/android_sdk_path': str(tools['sdk']),
              'export/android/debug_keystore': str(keystore),
              'export/android/debug_keystore_user': 'androiddebugkey',
              'export/android/debug_keystore_pass': 'android'}
    text = settings.read_text(encoding='utf-8') if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    for key, value in values.items():
        text = re.sub(r'^' + re.escape(key) + r' = .*\n?', '', text, flags=re.M)
        text += key + ' = ' + cfg_path(value) + '\n'
    settings.write_text(text, encoding='utf-8')


def export_presets(project, tools, target, stamp, code):
    common = '''[preset.0]
name="Headset"
platform="%s"
runnable=true
export_filter="all_resources"
include_filter="bundled-content/*.json,bundled-content/*.zip,*.ogv"
exclude_filter="verify*.gd,bake*.gd,probe*.gd,probe*.tscn,capture*.gd,builder_*.gd"
export_path=""

[preset.0.options]
'''
    if target == 'frame':
        template = tools['templates']/'linux_release.arm64'
        preset = common % 'Linux'
        preset += f'custom_template/release={cfg_path(template)}\ncustom_template/debug={cfg_path(template)}\n'
        preset += 'binary_format/architecture="arm64"\nbinary_format/embed_pck=true\ntexture_format/s3tc_bptc=false\ntexture_format/etc2_astc=true\n'
    else:
        preset = common % 'Android'
        preset += f'gradle_build/use_gradle_build=true\ngradle_build/gradle_build_directory="res://android"\n'
        preset += f'gradle_build/android_source_template={cfg_path(tools["templates"]/"android_source.zip")}\n'
        preset += '''gradle_build/min_sdk="29"
gradle_build/target_sdk="36"
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
package/unique_name="org.crocvr.prototype"
package/name="Croc VR Quest 3"
package/signed=true
package/show_in_app_library=true
user_data_backup/allow=false
screen/immersive_mode=true
xr_features/xr_mode=1
xr_features/enable_meta_plugin=true
xr_features/enable_khronos_plugin=false
permissions/vibrate=true
permissions/internet=false
'''
        preset += f'version/code={code}\nversion/name="{stamp}"\n'
        preset += f'keystore/release={cfg_path(WORKSPACE/".cache/signing/croc-vr.keystore")}\nkeystore/release_user="androiddebugkey"\nkeystore/release_password="android"\n'
    (project/'export_presets.cfg').write_text(preset, encoding='utf-8')


def preflight(tools, target, runner):
    node = str(tools['node']) if tools.get('node') else shutil.which('node')
    if not node:
        raise RuntimeError('Install Node.js 22 or newer to run the disc importer.')
    runner.run([node, '-e', 'if(Number(process.versions.node.split(".")[0])<22)process.exit(1)'], env=external_environment())
    options = {'creationflags': subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {}
    version = subprocess.check_output([tools['godot'], '--version'], text=True, env=external_environment(), **options).strip()
    if not version.startswith('4.7.2.stable'):
        raise RuntimeError('This source is tested with Godot 4.7.2-stable. Selected editor: ' + version)
    needed = ['linux_release.arm64'] if target == 'frame' else ['android_source.zip']
    if target == 'both':
        needed += ['linux_release.arm64']
    for name in needed:
        if not (tools['templates']/name).is_file():
            raise RuntimeError('Missing matching Godot export template: ' + name)
    if target in ('both', 'quest'):
        extension = tools['vendors']/'godotopenxrvendors/plugin.gdextension'
        if not extension.exists():
            raise RuntimeError('--vendors must point to the addons directory containing godotopenxrvendors.')
        java = tools['java']/('bin/java.exe' if os.name == 'nt' else 'bin/java')
        info = subprocess.run([java, '-version'], text=True, capture_output=True, env=external_environment(), **options)
        if info.returncode or not re.search(r'version "17[.\"]', info.stderr + info.stdout):
            raise RuntimeError('Quest exports require a JDK 17 installation in --java / JAVA_HOME.')
        if not (tools['sdk']/'platforms/android-36/android.jar').exists():
            raise RuntimeError('Android SDK platform 36 is missing; see docs/setup.md.')
        if not (tools['sdk']/'build-tools/36.1.0').exists():
            raise RuntimeError('Android build-tools 36.1.0 are missing; see docs/setup.md.')
    return node


def build(args, log=print):
    tools = paths(args)
    runner = Runner(log)
    node = preflight(tools, args.target, runner)
    disc = Path(args.iso).expanduser().resolve()
    if not disc.is_file():
        raise RuntimeError('Select an existing Croc PlayStation .bin or .iso file.')
    if Path(args.output).expanduser().exists():
        raise RuntimeError('Output already exists. Choose a new folder.')
    # Validate before creating a work directory or performing a lengthy import.
    runner.run([node, ROOT/'engine/tools/check-disc.cjs', disc])
    source_hash = source_identity()
    log('Hashing the selected disc…')
    disc_hash = digest(disc)
    job = WORKSPACE/'build'/('job-' + uuid.uuid4().hex[:12])
    job.mkdir(parents=True)
    tools = isolated_editor(tools, job)
    content = job/'content'
    project = job/'project'
    shutil.copytree(ROOT/'engine/game', project, ignore=shutil.ignore_patterns('.godot', 'android', 'addons', '*.import', 'argonaut-logo.ogv'))
    config_file = project/'project.godot'
    config = config_file.read_text(encoding='utf-8')
    config = config.replace('[application]', '[application]\nconfig/icon="res://app-icon.svg"')
    # Packaging must always start from the self-contained bootstrap.
    config = config.replace('run/main_scene="res://imported.tscn"', 'run/main_scene="res://quest_bundled_bootstrap.tscn"')
    config += '\n[audio]\ndriver/enable_input=false\n'
    config_file.write_text(config, encoding='utf-8')
    # Isolate editor settings and signing files from the user's Godot preferences.
    env = external_environment()
    env['NODE_OPTIONS'] = '--max-old-space-size=8192'
    env['GRADLE_USER_HOME'] = str(WORKSPACE/'.cache/gradle')
    settings = job/'editor-home'
    env.update({'XDG_CONFIG_HOME': str(settings/'config'), 'XDG_DATA_HOME': str(settings/'data'),
                'APPDATA': str(settings/'config'), 'LOCALAPPDATA': str(settings/'data')})
    if 'java' in tools:
        env['JAVA_HOME'] = str(tools['java'])
        env['PATH'] = str(tools['java']/'bin') + os.pathsep + env.get('PATH', '')
        env['ANDROID_HOME'] = env['ANDROID_SDK_ROOT'] = str(tools['sdk'])

    def engine(script=None, *extra):
        command = [tools['godot'], '--headless', '--xr-mode', 'off', '--path', project]
        if script:
            command += ['--script', 'res://' + script, '--', '--content', content]
        runner.run(command + list(extra), env=env, godot=True)

    def importer(name, *extra):
        runner.run([node, ROOT/'engine/tools'/name, *extra], cwd=ROOT, env=env)

    log('Importing the selected disc locally. This may take several minutes.')
    importer('import-backup.cjs', disc, content)
    manifest = read_json(content/'manifest.json')
    if manifest['sourceSha256'] != disc_hash:
        raise RuntimeError('Disc changed during import. Select an unchanged backup and retry.')
    for field in ('runtimeTables', 'cutsceneSequences', 'cutsceneAudio', 'cutsceneSequenceAudio', 'musicIndex'):
        if not manifest.get(field):
            raise RuntimeError('This disc is not supported by the full VR importer: missing ' + field)
    for name in ('refresh-camera-redirects.cjs', 'import-background-colors.cjs', 'import-terrain-palette-cycles.cjs'):
        importer(name, content)
    importer('publish-options-font.cjs', disc, content)
    importer('publish-save-icon.cjs', disc, content, job/'save-icon-preview.png')
    importer('import-startup-movie.cjs', disc, tools['ffmpeg'], project/'argonaut-logo.ogv', job/'startup.str')
    engine(None, '--editor', '--import')
    log('Preparing cutscenes. This step may take a while.')
    for script in ('bake_cutscene_meshes.gd', 'bake_cutscene_background.gd', 'bake_cutscene_compositor.gd', 'bake_sad_portals.gd'):
        engine(script)
    manifest = read_json(content/'manifest.json')
    tables = read_json(content/manifest['runtimeTables'])
    # These are the opening, end sequences and boss-defeat cinematics used by
    # the current VR runtime. Boss introductions use their gameplay actors.
    for scene in (0, 7, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19):
        record = tables['gameOver']['sequenceScenes']['records'][scene]
        log(f'Preparing cinematic scene {scene} ({record["prefix"]})…')
        engine('bake_compact_sequence.gd', '--scene', scene)
    plan = job/'inventory.json'
    make_plan(content, plan)
    compact = job/'compact-plan.json'
    runner.run(python_command(ROOT/'engine/tools/plan-quest3-slim.py', content, compact, plan))
    bundle = job/'bundle'
    runner.run(python_command(ROOT/'engine/tools/package-quest-bundled-content.py', compact, bundle))
    bundle_index = read_json(bundle/'index.json')
    destination = project/'bundled-content'
    destination.mkdir()
    shutil.copy2(bundle/'index.json', destination/'index.json')
    for pack in bundle_index['packs']:
        shutil.copy2(contained(bundle, pack['archive']), destination/pack['archive'])
    # Keep provenance and prepared data for inspection and export recovery.
    write_json(job/'prepared.json', {'schema': 1, 'sourceSha256': disc_hash, 'engineSha256': source_hash,
                                    'project': str(project), 'tools': {k: str(v) for k,v in tools.items()}})
    log('Game data is ready. Creating your app…')
    return export(args, project, tools, source_hash, disc_hash, bundle_index, env, runner, job)


def export(args, project, tools, source_hash, disc_hash, bundle_index, env, runner, job):
    tools = isolated_editor(tools, job)
    output = Path(args.output).expanduser().resolve()
    if output.exists():
        raise RuntimeError('Output already exists. Choose a new folder to preserve previous apps.')
    # Signed Android version codes remain below INT32_MAX through 2038.
    now = datetime.now(timezone.utc)
    code = int(now.timestamp())
    stamp = now.strftime('%Y.%m.%d.%H%M%S')
    outputs = []
    targets = ('frame', 'quest') if args.target == 'both' else (args.target,)
    stage = job/'finished'
    stage.mkdir(exist_ok=True)
    for target in targets:
        if target == 'quest':
            shutil.copytree(tools['vendors'], project/'addons', dirs_exist_ok=True)
            # Godot's Android source template is a Gradle project rooted at android/build.
            from .common import unpack
            unpack(tools['templates']/'android_source.zip', project/'android/build')
            (project/'android/.gdignore').write_text('', encoding='utf-8')
            import hashlib
            template = tools['templates']/'android_source.zip'
            template_id = str(template).replace('\\', '/') + ' [' + hashlib.md5(template.read_bytes()).hexdigest() + ']'
            (project/'android/.build_version').write_text(template_id, encoding='utf-8')
            if os.name != 'nt':
                (project/'android/build/gradlew').chmod(0o755)
            gradle = project/'android/build/build.gradle'
            text = gradle.read_text(encoding='utf-8')
            text = text.replace('        aaptOptions {', '        aaptOptions {\n            noCompress "zip"')
            gradle.write_text(text, encoding='utf-8')
            properties = project/'android/build/gradle.properties'
            text = properties.read_text(encoding='utf-8')
            text = re.sub(r'^org.gradle.daemon=.*\n?', '', text, flags=re.M)
            text += '\norg.gradle.daemon=false\norg.gradle.workers.max=2\n'
            properties.write_text(text, encoding='utf-8')
            android_editor_settings(tools, signing_key(tools, runner, env))
        export_presets(project, tools, target, stamp, code)
        if target == 'frame':
            runner.run([tools['godot'], '--headless', '--xr-mode', 'off', '--path', project,
                        '--editor', '--import'], env=env, godot=True)
        name = 'croc-vr-frame.arm64' if target == 'frame' else 'croc-vr-quest3.apk'
        artifact = stage/name
        log = runner.log
        log('Exporting ' + target + ' with bundled data…')
        runner.run([tools['godot'], '--headless', '--xr-mode', 'off', '--path', project,
                    '--export-release', 'Headset', artifact], env=env, godot=True)
        size = require_small(artifact)
        if target == 'frame':
            with artifact.open('rb') as stream:
                header = stream.read(20)
            if header[:4] != b'\x7fELF' or int.from_bytes(header[18:20], 'little') != 183:
                raise RuntimeError('Frame output is not a native AArch64 ELF.')
            artifact.chmod(0o755)
            runner.run([tools['godot'], '--headless', '--xr-mode', 'off', '--main-pack', artifact,
                        '--script', ROOT/'scripts/verify-frame-data.gd'], env=env, godot=True)
        else:
            java = tools['java']/('bin/java.exe' if os.name == 'nt' else 'bin/java')
            apksigner = tools['sdk']/'build-tools/36.1.0/lib/apksigner.jar'
            runner.run([java, '-jar', apksigner, 'verify', '--verbose', artifact], env=env)
            import zipfile
            with zipfile.ZipFile(artifact) as apk:
                if 'lib/arm64-v8a/libgodot_android.so' not in apk.namelist():
                    raise RuntimeError('Quest output is missing its ARM64 Godot runtime.')
                packaged_index = json.loads(apk.read('assets/bundled-content/index.json'))
                if packaged_index != bundle_index:
                    raise RuntimeError('Quest bundled-data index differs from the prepared import.')
                import hashlib
                for pack in bundle_index['packs']:
                    archive_member = 'assets/bundled-content/' + pack['archive']
                    h = hashlib.sha256()
                    with apk.open(archive_member) as stream:
                        for block in iter(lambda: stream.read(1024*1024), b''):
                            h.update(block)
                    if h.hexdigest() != digest(project/'bundled-content'/pack['archive']):
                        raise RuntimeError('Quest bundled archive changed during export: ' + pack['archive'])
        checksum = digest(artifact)
        (stage/(name + '.sha256')).write_text(checksum + '  ' + name + '\n', encoding='utf-8')
        outputs.append({'target': target, 'file': name, 'bytes': size, 'sha256': checksum})
    report = {'schema': 1, 'builderVersion': __version__, 'builtAt': now.isoformat(), 'engineSha256': source_hash,
              'discSha256': disc_hash, 'godot': '4.7.2-stable', 'maxArtifactBytesExclusive': 1_000_000_000,
              'bundledData': True, 'isoOnHeadsetRequired': False, 'outputs': outputs,
              'firstRunUnpackedDataBytes': sum(p['bytes'] for p in bundle_index['packs']),
              'status': 'Build checks passed.'}
    write_json(stage/'build-report.json', report)
    (stage/'INSTALL.txt').write_text(installation_text(targets, tools), encoding='utf-8')
    # Copy to a sibling temporary folder and publish only after every target passed.
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(output.name + '.building-' + uuid.uuid4().hex[:8])
    shutil.copytree(stage, temporary)
    if output.exists():
        raise RuntimeError('Output appeared during build; existing files were preserved.')
    temporary.rename(output)
    runner.log('Build complete: ' + str(output))
    for item in outputs:
        runner.log(f'{item["file"]}: {item["bytes"] / 1_000_000:.1f} MB')
    return report


def signing_key(tools, runner, env):
    """Persistent, local-only sideload identity so future APKs can update in place."""
    key = WORKSPACE/'.cache/signing/croc-vr.keystore'
    key.parent.mkdir(parents=True, exist_ok=True)
    if not key.exists():
        keytool = tools['java']/('bin/keytool.exe' if os.name == 'nt' else 'bin/keytool')
        runner.run([keytool, '-genkeypair', '-noprompt', '-keystore', key, '-storepass', 'android',
                    '-alias', 'androiddebugkey', '-keypass', 'android', '-keyalg', 'RSA', '-keysize', '2048',
                    '-validity', '10000', '-dname', 'CN=Croc VR Local Build'], env=env)
        if os.name != 'nt':
            key.chmod(0o600)
    return key
