# AtNav

**Decentralized, End-to-End Encrypted Desktop Location Sharing on the Atsign Protocol**

> Zero centralized database. Zero middleman. Peer-to-peer encrypted coordinates.
> Your location data belongs to you — not a corporate server.

---

## The Problem

Modern location sharing applications (Google Maps sharing, Apple Find My, Life360) store granular, unencrypted GPS coordinates on central corporate databases. This creates:

- **Massive breach targets**: A single database compromise leaks millions of users' real-time locations
- **Unauthorized surveillance**: Third parties (employers, insurers, governments) can subpoena centralized location records
- **Data monetization**: Location data is sold to advertisers, hedge funds, and data brokers without meaningful consent
- **Single point of failure**: Service outages cut all users off simultaneously

## The Solution

AtNav eliminates the centralized privacy hole entirely by building on the **Atsign Protocol** — a fully decentralized, text-based protocol over TLS where every cryptographic identity (atSign) owns its own personal micro-server (atServer).

**How it works:**
1. Your coordinates are encrypted **on your device** using AES-256 with a key unique to each recipient
2. Encrypted blobs are transmitted peer-to-peer through your personal atServer
3. Your atServer **cannot decrypt** your data — it stores only opaque ciphertexts
4. Recipients decrypt locally using their private keys
5. **No central database** ever stores your coordinates

---

## Key Features

- **End-to-End Encryption**: AES-256-CTR encryption with RSA-2048 key exchange. Your atServer cannot read your data.
- **Decentralized Architecture**: No central server. Each atSign has its own micro-server.
- **Ephemeral Telemetry**: Location notifications expire in 60 seconds — they never hit the server commit log.
- **Local-Only Persistence**: Coordinates are stored only in a local SQLite database on the receiver's device.
- **Cross-Platform Desktop**: Native builds for Windows, macOS, and Linux.
- **Industrial Brutalist UI**: Tactical telemetry interface with CRT aesthetics, monospace readouts, and Aviation Red accents.
- **Real-Time Streaming**: Live coordinate updates every 5 seconds with animated map pins.
- **Multi-Peer Support**: Share with multiple atSigns simultaneously.
- **Trail History**: Polyline trails showing movement history (24-hour retention).
- **Automatic Cleanup**: Expired coordinates are purged every 10 minutes.

---

## Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| **Language** | Dart | ^3.7.2 |
| **Framework** | Flutter (Desktop) | Latest stable |
| **Protocol** | Atsign Protocol | at_client ^3.12.0 |
| **Authentication** | at_auth (PKAM) | ^3.0.0 |
| **Map Rendering** | flutter_map (OSM) | ^7.0.2 |
| **Local Database** | Drift (SQLite) | ^2.22.1 |
| **Location** | Geolocator | ^13.0.2 |
| **Typography** | Google Fonts | JetBrains Mono, Archivo Black |
| **Window Mgmt** | window_manager | ^0.4.3 |

---

## Prerequisites

Before running AtNav, you need:

1. **Flutter SDK** (latest stable channel with desktop support enabled)
   ```bash
   flutter config --enable-windows-desktop
   flutter config --enable-macos-desktop
   flutter config --enable-linux-desktop
   ```

2. **A registered atSign** — Get one free at [my.noports.com](https://my.noports.com/no-ports-plans) or [my.atsign.com](https://my.atsign.com)

3. **An `.atKeys` file** — Generated during atSign onboarding. This is your cryptographic identity.
   - If you don't have one yet, use the CLI tool:
     ```bash
     dart pub global activate at_onboarding_cli
     at_activate -a @your_atsign -c <cram_secret>
     ```
   - Your `.atKeys` file will be saved to `~/.atsign/keys/@your_atsign_key.atKeys`

4. **Platform-specific build tools:**
   - **Windows**: Visual Studio 2022 with Desktop C++ workload
   - **macOS**: Xcode 14+
   - **Linux**: `cmake`, `ninja-build`, `clang`, `libgtk-3-dev`

---

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd Atsignhackathon
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate Drift Database Code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run the Application

```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

### 5. Authenticate

1. Launch the app — you'll see the onboarding screen
2. Enter your atSign (e.g., `@alice`)
3. Click "SELECT .ATKEYS FILE" and browse to your `.atKeys` backup file
4. Click ">>> AUTHENTICATE"
5. Wait for the PKAM handshake to complete

### 6. Share Your Location

1. In the left panel, enter a peer's atSign in the "ADD PEER" field
2. Click the `+` button to add them
3. Click ">>> START STREAM" to begin broadcasting your coordinates
4. Your peer needs AtNav running with their own atSign to see your location

---

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the complete system architecture specification, including:

- System topology diagrams
- Cryptographic data-flow matrix (sender → wire → receiver)
- SQLite schema and query interface
- Notification lifecycle and `ttln` design rationale
- PKAM authentication flow
- Tactical Telemetry design system specification

### High-Level Data Flow

```
GPS → JSON → AES-256 Encrypt → atServer (opaque blob) → Peer atServer → Monitor → AES-256 Decrypt → SQLite → Map UI
```

### Directory Structure

```
lib/
├── main.dart                              # App entrypoint, window config
├── core/
│   ├── at_service.dart                    # AtClientManager wrapper, PKAM auth
│   └── constants.dart                     # App constants (namespace, TTL, intervals)
├── models/
│   └── telemetry_point.dart               # Immutable coordinate data class
├── features/
│   ├── publisher/
│   │   └── telemetry_streamer.dart        # GPS → Notify pipeline
│   ├── subscriber/
│   │   └── telemetry_listener.dart        # Monitor → Decrypt → SQLite pipeline
│   ├── storage/
│   │   ├── local_db.dart                  # Drift database definition
│   │   └── local_db.g.dart                # Generated Drift code
│   └── ui/
│       ├── theme.dart                     # Industrial Brutalist design tokens
│       ├── onboarding_screen.dart         # .atKeys authentication screen
│       ├── map_screen.dart                # Main map + dashboard (split-pane)
│       ├── peer_panel.dart                # Peer management sidebar
│       └── telemetry_ticker.dart          # Bottom real-time data feed
```

---

## Environment Variables

AtNav does not use environment variables or `.env` files. All configuration is hardcoded in `lib/core/constants.dart`:

| Constant | Value | Description |
|----------|-------|-------------|
| `appNamespace` | `AtNav` | Scopes all atKeys to this application |
| `rootDomain` | `root.atsign.org` | atDirectory lookup server |
| `telemetryIntervalSeconds` | `5` | GPS polling interval |
| `notificationTtlnMs` | `60000` | 60-second ephemeral notification TTL |
| `trailRetentionHours` | `24` | Local coordinate retention period |
| `maxTrailPoints` | `500` | Max polyline trail points per peer |

---

## Security Model

### Encryption

| Layer | Algorithm | Key Size | Purpose |
|-------|-----------|----------|---------|
| Value encryption | AES-256-CTR (PKCS7) | 256-bit | Coordinate payload encryption |
| Key exchange | RSA-2048 | 2048-bit | Shared key transport to recipient |
| Authentication | PKAM (RSA signature) | 2048-bit | Identity verification |
| Transport | TLS 1.3 | - | Wire-level encryption |

### Zero-Knowledge Architecture

The atServer is a **zero-knowledge host**:
- Stores only opaque ciphertexts
- Cannot decrypt values (no access to decryption keys)
- Cannot perform server-side filtering or analytics on location data
- Value-level filtering is always on-device

### Threat Model

| Threat | Mitigation |
|--------|------------|
| Server compromise | Zero-knowledge: server has no decryption keys |
| Man-in-the-middle | TLS 1.3 transport + E2E encryption |
| Replay attacks | Random IV nonce per notification + 60s TTL expiry |
| Key compromise | APKAM scoped keys: revocable, namespace-limited |
| Location history subpoena | Local-only storage: no central database to subpoena |

---

## Building for Production

```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

Compiled binaries will be in `build/<platform>/runner/Release/`.

---

## Troubleshooting

### Authentication Fails

**Error**: "PKAM authentication failed"

**Solutions**:
1. Verify your `.atKeys` file is valid and not corrupted
2. Ensure the atSign matches the one in the `.atKeys` file
3. Check internet connectivity — the app needs to reach `root.atsign.org:64`
4. Try re-generating your `.atKeys` file with `at_activate`

### No Location Data

**Error**: Location services unavailable

**Solutions**:
1. On desktop, GPS hardware is uncommon. Geolocator falls back to IP-based location
2. Ensure location services are enabled in your OS settings
3. Windows: Settings → Privacy → Location → Enable
4. macOS: System Preferences → Security & Privacy → Location Services

### Build Errors

**Error**: Drift code generation errors

**Solution**:
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Error**: Missing native libraries (Linux)

**Solution**:
```bash
sudo apt-get install cmake ninja-build clang libgtk-3-dev libsqlite3-dev
```

## Testing

To test AtNav across two different computers, follow these steps:

1. **Build the Application**: On your computer, run `flutter build windows` (or linux/macos). 
2. **Share the Executable**: Zip the contents of the `build/windows/x64/runner/Release/` directory and send it to your buddy.
3. **Run the App**: Your buddy can unzip it and double-click `atnav.exe` to run the application. No installation is required.
4. **Authenticate**: You authenticate with your `.atKeys` file, and your buddy authenticates with their own `.atKeys` file.
5. **Connect**: In the left sidebar under "Add Peer", type your buddy's atSign and hit enter. Your buddy does the same on their machine, typing *your* atSign.
6. **Start Tracking**: Both of you click "START STREAM". AtNav will instantly begin encrypting and sending location data back and forth directly via the Atsign protocol!

---

## Hackathon Context

Built for the **Atsign Hackathon** (June 25-26, 2026) to demonstrate the Atsign Protocol's capability for real-time, decentralized, end-to-end encrypted data sharing — proving that location privacy doesn't require trusting a central authority.

---

## License

BSD-3-Clause — See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- [Atsign Foundation](https://atsign.com) — The atProtocol and SDK
- [flutter_map](https://github.com/fleaflet/flutter_map) — OpenStreetMap rendering
- [Drift](https://drift.simonbinder.eu/) — Type-safe reactive SQLite
- [CartoDB](https://carto.com/basemaps/) — Dark mode map tiles
