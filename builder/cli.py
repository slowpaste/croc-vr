import argparse
from datetime import datetime
import os
from pathlib import Path
import sys
import subprocess

from . import __version__
from .common import ROOT, WORKSPACE


def parser():
    result = argparse.ArgumentParser(description='Make Croc VR apps from your PlayStation disc backup.')
    result.add_argument('--version', action='version', version=__version__)
    commands = result.add_subparsers(dest='command', required=True)
    commands.add_parser('ui', help='Open the desktop app')
    commands.add_parser('setup', help='Download the game build tools')
    commands.add_parser('update', help='Get the latest builder source from GitHub')
    build = commands.add_parser('build', help='Build headset apps under 1 GB each')
    build.add_argument('--iso', required=True, help='Your Croc PlayStation .bin or raw .iso backup')
    build.add_argument('--target', choices=['frame', 'quest', 'both'], default='both')
    build.add_argument('--output', default=str(WORKSPACE/'dist'/datetime.now().strftime('croc-vr-%Y%m%d-%H%M%S')))
    build.add_argument('--local-source', action='store_true', help='Build this copy without checking for updates')
    for name, help_text in {'godot':'Godot 4.7.2 executable', 'templates':'matching export templates directory',
                            'vendors':'OpenXR vendors addons directory', 'sdk':'Android SDK root',
                            'java':'JDK 17 root', 'ffmpeg':'FFmpeg executable with Theora and Vorbis encoders'}.items():
        build.add_argument('--' + name, help=help_text)
    desktop = commands.add_parser('desktop-build', help='Set up the tools and build an app')
    desktop.add_argument('--iso', required=True)
    desktop.add_argument('--target', choices=['frame', 'quest'], required=True)
    desktop.add_argument('--output', required=True)
    desktop.set_defaults(godot=None, templates=None, vendors=None, sdk=None, java=None, ffmpeg=None)
    return result


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if args.command == 'ui':
            from .desktop import launch
            launch()
        elif args.command == 'setup':
            from .toolchain import setup
            setup()
        elif args.command == 'update':
            from .pipeline import update_source
            update_source()
        elif args.command == 'desktop-build':
            from .portable import prepare, node
            from .common import Runner, external_environment
            from .pipeline import build
            disc = Path(args.iso).expanduser().resolve()
            if not disc.is_file():
                raise RuntimeError('Choose an existing Croc PlayStation disc backup.')
            importer = node()
            Runner().run([importer, ROOT/'engine/tools/check-disc.cjs', disc], env=external_environment())
            prepare(args.target, node_path=importer)
            build(args)
        elif args.command == 'build':
            from .pipeline import build, update_source
            if not args.local_source and update_source():
                forwarded = (sys.argv[1:] if argv is None else argv) + ['--local-source']
                os.execv(sys.executable, [sys.executable, str(ROOT/'croc_builder.py'), *forwarded])
            build(args)
        return 0
    except KeyboardInterrupt:
        print('Build cancelled.', file=sys.stderr)
        return 130
    except subprocess.CalledProcessError as error:
        detail = str(error.output or '').strip()
        print('Could not check for updates. ' + detail, file=sys.stderr)
        print('To build your current copy, add --local-source.', file=sys.stderr)
        return 1
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        print('Error: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
