# Contributing

Thanks for your interest in LanScope Mac.

## Development

1. Open `Package.swift` in Xcode.
2. Select the `LanScopeMac` scheme.
3. Run the app on My Mac.

From Terminal:

```bash
/bin/bash ./script/build_and_run.sh
swift test
```

## Pull Requests

- Keep changes focused.
- Run `swift test` before submitting.
- Do not add features for unauthorized scanning, stealth, credential attacks, exploitation, or bypassing network protections.
- Keep network behavior transparent and user-initiated.

## Privacy

LanScope Mac is local-first. Do not add external telemetry or cloud sync without explicit documentation and user control.
