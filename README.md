# HP LaserJet P1005 macOS Driver Patcher

A small Bash utility for patching legacy macOS `.pkg` printer driver installers that are blocked by macOS version checks.

Tested with the HP LaserJet P1005 driver package.

## What it does

- Expands a macOS `.pkg` installer
- Finds the `Distribution` file
- Patches XML-based macOS version checks
- Patches JavaScript-based checks such as `system.compareVersions(...)`
- Rebuilds a patched installer as `hpfix_work/fixed.pkg`

## Requirements

The script uses only built-in macOS tools:

- `pkgutil`
- `sed`
- `diff`
- `find`

Xcode, Homebrew, Python, Node.js, and Gutenprint are not required.

## Quick Start

If you already have `HewlettPackardPrinterDrivers.dmg` in your Downloads folder, you can run the full process like this:

```bash
cd ~/Desktop
git clone https://github.com/whotqq/hp-driver-patcher-LaserJet-p1005-.git
cd hp-driver-patcher-LaserJet-p1005-
chmod +x patch-driver.sh
hdiutil attach ~/Downloads/HewlettPackardPrinterDrivers.dmg
./patch-driver.sh /Volumes/HP_PrinterSupportManual/HewlettPackardPrinterDrivers.pkg
open hpfix_work/fixed.pkg
```

After the installer finishes, reconnect the printer and add it in:

```text
System Settings → Printers & Scanners
```

If the DMG is already mounted, you can skip the `hdiutil attach ...` command.

## Usage

```bash
chmod +x patch-driver.sh
./patch-driver.sh /path/to/HewlettPackardPrinterDrivers.pkg
```

Tip: type this command with a trailing space:

```bash
./patch-driver.sh 
```

Then drag the `.pkg` file into Terminal and press Enter.

## Example successful output

```text
[JS patch — Strategy A] compareVersions ceiling → '30.0'
[JS patch — Strategy B] 'return false' → 'return true' in check functions
[OK]    Fixed package → hpfix_work/fixed.pkg
```

## Important

This repository does not include HP drivers or proprietary files.

You must download the original driver package yourself.

Patched packages should not be redistributed.

## License

MIT
