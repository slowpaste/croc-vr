# What has been tested

## Completed checks

| Check | Result |
|---|---|
| Desktop app opens | Passed on Windows, Linux, Apple Silicon Macs and Intel Macs for v1.1.3. |
| Automatic Node and Java downloads | Downloaded, checked and run on all four computers. |
| Bundled video and data tools | Ran inside the packaged desktop apps. |
| Builder tests | 14 passed, including damaged downloads, file packing and Android setup using test files. |
| Disc importer | All 59 tests using the supported disc passed. |
| Game data | Checked 12 cutscene sequences, 92 audio channels and the first three gameplay rooms. |
| Steam Frame output | Built from the supported disc and checked at 899,130,544 bytes. |
| Facebook Shitface 3 output | Built from the same disc and checked at 915,456,500 bytes. |

These headset outputs were built on Windows through the shared source builder. Both include their game data.

## Checks on every finished app

The builder checks the file size and required game data. It also checks the Android app's signature. A failed build is not saved as a finished app.

`build-report.json` records the disc, builder version, file sizes and file checksums for that build.
