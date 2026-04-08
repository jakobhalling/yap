# Yap

A system tray app that enables voice-driven text input into any application. Activate with a global shortcut, speak, see a real-time transcript, optionally process it through Claude with customizable prompt profiles, and paste the result into any text field.

## Download

**[Download the latest Windows installer](https://github.com/jakobhalling/yap/releases/latest)**

The installer includes options for a desktop shortcut and launching at system startup (minimized to tray).

## Features

- Global hotkey activation (double-tap Right Ctrl) from any application
- Real-time streaming transcription via AssemblyAI
- Optional LLM processing through Anthropic Claude with customizable prompt profiles
- One-click paste into the previously focused text field
- Transcription history with search
- Configurable microphone selection, Claude model, and sound cues
- Launch on system startup with automatic update checking

## Building from source

Requires Flutter SDK (stable channel) and a Windows development environment.

```bash
flutter pub get
flutter build windows --release
```

To build the installer locally, install [Inno Setup 6](https://jrsoftware.org/isdl.php) and run:

```powershell
.\scripts\build_installer.ps1
```

## macOS Code Signing

The macOS build uses a self-signed certificate ("Yap Developer") so that accessibility permissions persist across app updates. Without a stable code signature, macOS revokes accessibility access every time the binary changes.

### Setup for CI

The release workflow expects two repository secrets:

- `MACOS_CERTIFICATE_B64` — base64-encoded .p12 certificate
- `MACOS_CERTIFICATE_PWD` — password for the .p12 file

To generate a new certificate (e.g., on a new machine or when it expires):

```bash
./installer/create_signing_cert.sh
```

This creates the certificate, imports it to your login keychain, and prints the base64 + password to add as GitHub repository secrets.

### Local development

The same certificate must be in your login keychain for local builds. Run the script above, then in Keychain Access (login keychain > Keys), set the private key's Access Control to allow `codesign`.

## Tech Stack

- **Framework:** Flutter (desktop)
- **State:** Riverpod
- **Storage:** SQLite via Drift ORM
- **Transcription:** AssemblyAI (real-time WebSocket)
- **LLM:** Anthropic Claude API
- **Platform:** Windows, macOS
