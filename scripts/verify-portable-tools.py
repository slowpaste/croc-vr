"""Network integration check: real vendor tools, without accepting SDK terms."""
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from builder.common import external_environment
from builder.portable import node, java, sdk_manifest, sdk_selection, host

n = node()
subprocess.run([n, '--version'], check=True, env=external_environment())
j = java()
subprocess.run([j/('bin/java.exe' if sys.platform == 'win32' else 'bin/java'), '-version'], check=True, env=external_environment())
for package in sdk_selection(sdk_manifest()):
    print('VERIFIED_SDK_METADATA', package['package'], package['file'])
print('PASS: private Node and JDK downloads, extraction and execution on', host())
