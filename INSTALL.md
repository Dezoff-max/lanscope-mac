# LanScope Mac Installation

## Standard Installation

1. Open `LanScope Mac.dmg`.
2. Drag `LanScope Mac.app` to the `Applications` folder.
3. Launch the app from `Applications`.

## If macOS Blocks The App

The current MVP DMG is unsigned and not notarized. If macOS blocks launch, try the safer method first:

1. Open `Applications`.
2. Right-click `LanScope Mac.app`.
3. Choose `Open`.
4. Confirm the launch.

## Temporary Gatekeeper Override

If the app still does not launch and you trust this DMG, you can temporarily disable Gatekeeper:

```bash
sudo spctl --master-disable
```

After the first successful launch, enable Gatekeeper again:

```bash
sudo spctl --master-enable
```

Important: do not leave Gatekeeper disabled permanently. This setting affects the security of the whole system.

## Build From Source

```bash
swift test
/bin/bash ./script/build_and_run.sh
```

To build a local DMG:

```bash
/bin/bash ./script/package_dmg.sh
```
