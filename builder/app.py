"""Frozen executable entry point, internal workers, and packaged-app smoke test."""
import json
import os
from pathlib import Path
import runpy
import sys


def main():
    from .common import FROZEN, ROOT, WORKSPACE
    arguments = sys.argv[1:]
    if arguments and arguments[0] == '--python-script':
        script = Path(arguments[1]).resolve()
        allowed = { (ROOT/'engine/tools'/name).resolve() for name in ('plan-quest3-slim.py', 'package-quest-bundled-content.py') }
        if script not in allowed:
            raise RuntimeError('Unknown internal packaging script')
        sys.argv = [str(script), *arguments[2:]]
        runpy.run_path(str(script), run_name='__main__')
        return 0
    if arguments and arguments[0] == '--worker':
        from .cli import main as cli_main
        if FROZEN and os.name == 'nt':
            import ctypes
            ctypes.windll.kernel32.SetDllDirectoryW(None)
        return cli_main(arguments[1:])
    if arguments and arguments[0] == '--smoke-test':
        from .smoke import verify
        report = verify()
        # Windowed executables have no console; a report file is the contract.
        Path(arguments[1]).write_text(json.dumps(report, indent=2))
        return 0
    from .desktop import launch
    launch()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
