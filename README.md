# HP LaserJet P1005 macOS Driver Patcher

A small Bash utility for patching legacy macOS `.pkg` printer driver installers that are blocked by macOS version checks.

Tested with HP LaserJet P1005 driver package.

## What it does

- Expands a macOS `.pkg` installer
- Finds the `Distribution` file
- Patches XML-based macOS version checks
- Patches JavaScript-based checks such as `system.compareVersions(...)`
- Rebuilds a patched installer as `hpfix_work/fixed.pkg`

## Usage

```bash
chmod +x patch-driver.sh
./patch-driver.sh /path/to/HewlettPackardPrinterDrivers.pkg# HP LaserJet P1005 macOS Driver Patcher

A small Bash utility for patching legacy macOS `.pkg` printer driver installers that are blocked by macOS version checks.

Tested with HP LaserJet P1005 driver package.

## What it does

- Expands a macOS `.pkg` installer
- Finds the `Distribution` file
- Patches XML-based macOS version checks
- Patches JavaScript-based checks such as `system.compareVersions(...)`
- Rebuilds a patched installer as `hpfix_work/fixed.pkg`

## Usage

```bash
chmod +x patch-driver.sh
./patch-driver.sh /path/to/HewlettPackardPrinterDrivers.pkg
```

Tip: type:

```bash
./patch-driver.sh 
```

Then drag the `.pkg` file into Terminal.

## Important

This repository does not include HP drivers or proprietary files.

You must download the original driver package yourself.

Patched packages should not be redistributed.

## License

MIT# HP LaserJet P1005 macOS Driver Patcher

A small Bash utility for patching legacy macOS `.pkg` printer driver installers that are blocked by macOS version checks.

Tested with HP LaserJet P1005 driver package.

## What it does

- Expands a macOS `.pkg` installer
- Finds the `Distribution` file
- Patches XML-based macOS version checks
- Patches JavaScript-based checks such as `system.compareVersions(...)`
- Rebuilds a patched installer as `hpfix_work/fixed.pkg`

## Usage

```bash
chmod +x patch-driver.sh
./patch-driver.sh /path/to/HewlettPackardPrinterDrivers.pkg
```

Tip: type:

```bash
./patch-driver.sh 
```

Then drag the `.pkg` file into Terminal.

## Important

This repository does not include HP drivers or proprietary files.

You must download the original driver package yourself.

Patched packages should not be redistributed.

## License

MIT
