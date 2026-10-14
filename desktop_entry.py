"""Packaged desktop executable; source users can also run this file."""
import sys


if __name__ == '__main__':
    if '--worker' in sys.argv or '--python-script' in sys.argv:
        # Persist worker output even in a windowed Windows/macOS executable.
        # The GUI starts each worker with its own log path.
        import os
        path = os.environ.get('CROC_WORKER_LOG')
        if path:
            sys.stdout = sys.stderr = open(path, 'a', encoding='utf-8', buffering=1)
    from builder.app import main
    try:
        raise SystemExit(main())
    except Exception:
        import traceback
        traceback.print_exc()
        raise SystemExit(1)
