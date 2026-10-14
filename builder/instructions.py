"""Short installation steps saved beside each finished headset app."""
import os
from pathlib import Path
import shlex


def installation_text(targets, tools):
    sections = ['croc of slop VR - Install your app\n']
    if 'frame' in targets:
        sections.append('''STEAM FRAME

1. Copy croc-vr-frame.arm64 to your headset.
2. On the headset, open a terminal in that folder.
3. Run:
   chmod +x croc-vr-frame.arm64
4. Add the file to Steam as a non-Steam game.
5. Launch it in VR.
''')
    if 'quest' in targets:
        sdk = tools.get('sdk')
        adb = Path(sdk)/'platform-tools'/('adb.exe' if os.name == 'nt' else 'adb') if sdk else Path('adb')
        if not adb.is_file():
            adb = Path('adb')
        if os.name == 'nt':
            command = "& '" + str(adb).replace("'", "''") + "' install -r 'croc-vr-quest3.apk'"
        else:
            command = shlex.join([str(adb), 'install', '-r', 'croc-vr-quest3.apk'])
        sections.append('''FACEBOOK SHITFACE 3

1. Enable developer mode and USB debugging on your headset.
2. Connect it to your computer by USB. Allow the connection on the headset.
3. Open a terminal in this app folder. On Windows, use PowerShell.
4. Run:
   ''' + command + '''
5. Open the Croc VR app from Unknown Sources.
''')
    sections.append('''Your game data is already included. Keep the disc image on your computer.

Each app file is under 1 GB. Allow more than 2 GB on the headset for installation.
The first launch unpacks the game; wait for it to finish.
''')
    return '\n'.join(sections)
