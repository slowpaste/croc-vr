#!/usr/bin/env python3
"""Shared entry point: Linux CLI and Windows/macOS/Linux desktop interface."""
from builder.cli import main

if __name__ == '__main__':
    raise SystemExit(main())
