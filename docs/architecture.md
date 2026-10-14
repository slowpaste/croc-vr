# How it works

The desktop app and Linux script use the same builder.

1. Check your Croc PlayStation backup.
2. Read the game data from your disc on your computer.
3. Prepare the levels, characters, menus, sound and cutscenes for VR.
4. Pack the data inside a Steam Frame app or Facebook Shitface 3 APK.
5. Check the finished file before saving it to a new folder.

The headset app unpacks its included data on first launch, then starts the game. You never select or copy a disc image on the headset. No streaming computer is needed to play.

Each app file must be under 1 GB. Installation and unpacking need more than 2 GB on the headset. The builder does not remove levels to meet the file limit.

## Setup and updates

The desktop download includes Python and the video tool. It downloads the other tools automatically and checks them for damage. Android setup shows Google's terms for you to accept.

Each desktop release includes its own copy of the builder. Download the newest release to update it. The Linux script checks GitHub for newer source unless you use `--local-source`.

## Where files go

Finished desktop builds go in **Croc of Slop VR** in your home folder. Click **Open finished apps** to find them.

Tools, work files and settings stay in the app's `croc-of-slop-vr` folder:

| Computer | Location |
|---|---|
| Windows | `%LOCALAPPDATA%/croc-of-slop-vr` |
| Mac | `~/Library/Application Support/croc-of-slop-vr` |
| Linux | `~/.local/share/croc-of-slop-vr`, or your `XDG_DATA_HOME` folder |

Source builds use the repository folder instead. Keep `.cache/signing/croc-vr.keystore` if you want future APKs to update an existing installation.

The builder does not upload your disc or finished apps. Download checks are listed in [tool-lock.json](../builder/tool-lock.json). Test results are in [validation](validation.md).
