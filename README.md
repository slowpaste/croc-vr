# croc of slop VR

Build a Steam Frame app or Facebook Shitface 3 APK from your own **Croc: Legend of the Gobbos PlayStation disc backup**. The finished app includes the game data. Your disc image stays on your computer.

## 1. Download the app

Choose the download for your computer from the [latest release](https://github.com/slowpaste/croc-vr/releases/latest):

| Your computer | Download | Open it |
|---|---|---|
| Windows | [Windows app](https://github.com/slowpaste/croc-vr/releases/latest/download/croc-of-slop-vr-windows-x64.exe) | Double-click the downloaded file. |
| Mac with Apple Silicon | [Mac app — Apple Silicon](https://github.com/slowpaste/croc-vr/releases/latest/download/croc-of-slop-vr-macos-arm64.dmg) | Open the download, drag the app into Applications, then open it. |
| Mac with Intel | [Mac app — Intel](https://github.com/slowpaste/croc-vr/releases/latest/download/croc-of-slop-vr-macos-x64.dmg) | Open the download, drag the app into Applications, then open it. |
| Linux (x64) | [Linux app](https://github.com/slowpaste/croc-vr/releases/latest/download/croc-of-slop-vr-linux-x64.tar.gz) | Extract the download, then open `croc-of-slop-vr`. |

You do not need the source ZIP or a separate Python installation. Your computer may ask for first-launch approval; these downloads are unsigned.

## 2. Choose your disc

Click **Choose .bin file…** and select your Croc PlayStation `.bin` backup. Raw `.iso` backups are also supported. If your disc version is unsupported, the app will tell you.

## 3. Click your headset

Click **Build for Steam Frame** or **Build for Facebook Shitface 3**.

The app downloads its build tools automatically. The first setup needs internet and downloads a few GB. Android setup also asks you to review and accept Google's SDK terms once.

Leave the app open while it prepares the game. This can take a long time.

## 4. Find your finished app

Click **Open finished apps**. This folder contains your headset app and `INSTALL.txt` with installation instructions.

You never need to copy or select the disc image on the headset. Each finished app file is under 1 GB; allow more than 2 GB of headset storage for installation and unpacking.

For the Linux script or editable source, see the [manual setup instructions](docs/setup.md).
