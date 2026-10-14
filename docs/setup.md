# Manual setup

For the easiest option, use the [downloadable app](desktop-release.md). It handles setup for you.

These steps are for the Linux script or editable source.

## 1. Get the source

Download and extract the source ZIP from [Releases](https://github.com/slowpaste/croc-vr/releases/latest), or use Git:

```sh
git clone https://github.com/slowpaste/croc-vr.git
cd croc-vr
```

Open a terminal in the source folder before running the commands below.

## 2. Install the tools

Install **Python 3.10+**, **Node.js 22+** and **FFmpeg**. Make sure the terminal can find them. The desktop window also needs Python's Tkinter component.

On Debian or Ubuntu:

```sh
sudo apt install python3 python3-tk ffmpeg git
```

Install Node.js 22 or newer separately if your package manager provides an older version. On Windows, include Tcl/Tk when installing Python. Mac users also need a Python installation with Tkinter.

Then download the game build tools:

```sh
python3 croc_builder.py setup
```

On Windows, use `python` instead of `python3`.

## 3. Set up Android tools, if needed

Skip this step for Steam Frame builds.

Install **Java 17** and the **Android SDK**. With Android's command-line tools, run:

```sh
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.1.0" "cmdline-tools;latest"
sdkmanager --licenses
```

Review and accept Google's terms yourself. Set `JAVA_HOME` to your Java 17 folder and `ANDROID_HOME` to your Android SDK folder. You do not need the Android NDK.

## 4. Build your app

On Linux:

```sh
bash scripts/build-linux.sh --local-source --iso "/path/to/Croc.bin" --target frame
```

Replace `/path/to/Croc.bin` with your backup's location. Use `--target quest` for Facebook Shitface 3, or `--target both` for both headsets.

On Windows or Mac, use the shared command instead:

```sh
python3 croc_builder.py build --local-source --iso "/path/to/Croc.bin" --target frame
```

Keep `--local-source` when using a source ZIP. Git users can omit it to check for source updates before building.

For the desktop window, run `python3 croc_builder.py ui`. It downloads its build tools automatically; Python/Tkinter and FFmpeg must already be installed when running from source.

## If something goes wrong

- **Download failed:** check your connection and try again.
- **Disc not supported:** use an original PlayStation `.bin` or raw `.iso` backup. PC, Saturn, Croc 2 and remaster discs will not work.
- **Only a cooked ISO is available:** use the original raw backup instead. Cooked ISOs omit needed audio and movie data.
- **APK will not update:** keep the same signing key between builds. A build made with a different key may require a reinstall.

Open **Details** in the app, or read the terminal error, for the exact problem.

<details>
<summary>Tool paths and supported disc version</summary>

Use `--godot`, `--templates`, `--vendors`, `--sdk`, `--java` or `--ffmpeg` to select existing tool folders. The same values can be set with `CROC_GODOT`, `CROC_TEMPLATES`, `CROC_VENDORS`, `CROC_SDK`, `CROC_JAVA` and `CROC_FFMPEG`.

- Godot: 4.7.2 editor.
- Templates: folder containing `linux_release.arm64` and `android_source.zip`.
- Vendors: `addons` folder containing `godotopenxrvendors`.
- Java: JDK 17 root folder.
- SDK: Android SDK root folder, with platform 36 and build-tools 36.1.0.
- FFmpeg: executable with Theora and Vorbis encoding.

The supported PlayStation backup uses 2352-byte sectors. Its `CROC.EXE` SHA-256 is `f2a62a1e9741bbfa3c0186a878caefbaea72aa12dc2936f709bbefc2256a6996`.

</details>
