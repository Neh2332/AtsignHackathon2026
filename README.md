**Presentation Link**: [https://youtu.be/pfS5lbJ6dRM](url)
# AtNav

Decentralized, End-to-End Encrypted Desktop and Mobile Location Sharing built on the Atsign Protocol. This application eliminates centralized location databases by leveraging peer-to-peer micro-servers (atServers) and AES-256-CTR encryption, ensuring only you and your trusted peers can access your coordinates.

## Key Features

- **End-to-End Encryption**: AES-256-CTR encryption with RSA-2048 key exchange.
- **Decentralized Architecture**: No central location server.
- **Granular Outbound Streaming**: Choose exactly which connected peers can see your location.
- **Infinite Duration Control**: Location streams run infinitely until manually stopped.
- **Ephemeral Telemetry**: Location notifications expire in 60 seconds.
- **Local-Only Persistence**: Coordinates stored only in a local SQLite database (via Drift).
- **Cross-Platform**: Adaptive layouts supporting Android, iOS, macOS, Windows, and Linux.
- **Industrial Brutalist UI**: Tactical telemetry interface with CRT aesthetics and adaptive responsive design.

## Tech Stack

- **Language**: Dart (^3.7.2)
- **Framework**: Flutter (Mobile & Desktop)
- **Protocol**: Atsign Protocol (`at_client` ^3.12.0, `at_auth` ^3.0.0, `at_commons` ^5.9.0)
- **Map Rendering**: `flutter_map` (^7.0.2), `latlong2` (^0.9.1)
- **Local Database**: `drift` (^2.22.1), `sqlite3_flutter_libs`
- **Location Services**: `geolocator` (^13.0.2)
- **State Management**: `provider` (^6.1.2)
- **Window Management**: `window_manager` (^0.4.3) (Desktop only)
- **Typography**: `google_fonts` (^6.2.1)

## Prerequisites

Before running AtNav, ensure you have the following installed:

- **Flutter SDK** (Latest stable)
  ```bash
  # For Desktop platforms:
  flutter config --enable-windows-desktop
  flutter config --enable-macos-desktop
  flutter config --enable-linux-desktop
  ```
- **A registered atSign** (Get one free at my.atsign.com)
- **An `.atKeys` file** (Generated during atSign onboarding)
- **Android Emulator / iOS Simulator** (If testing on mobile)

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/your-repo/Atsignhackathon.git
cd Atsignhackathon
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate Database Models (Drift)

The project relies on generated code for its SQLite storage layer. You must run `build_runner` to generate `local_db.g.dart`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run the Application

Launch the application on your desired target:

```bash
# Android (Requires connected physical device or emulator)
flutter run -d android

# iOS (Requires Simulator or physical device)
flutter run -d ios

# Windows Desktop
flutter run -d windows

# macOS Desktop
flutter run -d macos

# Linux Desktop
flutter run -d linux
```

### 5. Authenticate

1. Launch the app and view the onboarding screen.
2. Enter your atSign (e.g., `@alice`).
3. Click "SELECT .ATKEYS FILE" and browse to your `.atKeys` backup file.
4. Click ">>> AUTHENTICATE" to initiate the PKAM handshake.

### 6. Share Location

1. In the sidebar (desktop) or bottom sheet (mobile), enter a peer's atSign in the "ADD PEER" field.
2. Click `+` to initiate a consent request.
3. Toggle the "Outbound" switch to allow the peer to see your location.
4. Click ">>> START STREAM" to begin broadcasting your encrypted GPS coordinates.

## Architecture

### Directory Structure

```
├── android/                   # Native Android host app
├── build/                     # Build outputs
├── ios/                       # Native iOS host app
├── lib/
│   ├── core/                  # Core services and configuration
│   │   ├── at_service.dart    # Atsign authentication and base services
│   │   └── constants.dart     # App-wide constants
│   ├── features/              # Feature modules
│   │   ├── publisher/         # Outbound telemetry logic (TelemetryStreamer)
│   │   ├── storage/           # Local SQLite database (Drift)
│   │   ├── subscriber/        # Inbound telemetry logic (TelemetryListener)
│   │   └── ui/                # UI components (MapScreen, PeerPanel, etc.)
│   ├── models/                # Data models (TelemetryPoint)
│   └── main.dart              # Application entrypoint
├── linux/                     # Native Linux host app
├── macos/                     # Native macOS host app
└── windows/                   # Native Windows host app
```

### Data Flow

```
TelemetryStreamer (Sender)
1. Poll GPS via Geolocator
2. Construct TelemetryPoint
3. atClient (SDK) encrypts using AES-256-CTR
4. Notification sent with ttln=60000 (expires in 60s)
         ↓
atServer (Opaque Ciphertext Storage)
         ↓
TelemetryListener (Receiver)
1. Monitor Socket receives notification
2. atClient (SDK) auto-decrypts payload
3. Parse JSON to TelemetryPoint
4. Insert into LocalDb (Drift/SQLite)
         ↓
MapScreen (UI)
1. Reactive stream watches LocalDb
2. Updates MapPins and Trails dynamically
```

### Key Components

- **TelemetryStreamer (`lib/features/publisher`)**: Polls the device location and uses the `NotificationService` to fan-out E2E encrypted updates.
- **TelemetryListener (`lib/features/subscriber`)**: Monitors incoming notifications from authorized peers, decrypts payloads, and writes directly to local SQLite.
- **LocalDb (`lib/features/storage`)**: A SQLite database managed via Drift, housing the `Coordinates` and `PeerConsents` tables.
- **MapScreen (`lib/features/ui`)**: Responsive Flutter Map interface incorporating `latlong2` projections and reactive Drift streams.

### Database Schema

```sql
coordinates
├── id (integer, PK, auto-increment)
├── peer_atsign (text)
├── latitude (real)
├── longitude (real)
├── accuracy (real)
├── timestamp (text, ISO-8601 UTC sender clock)
└── received_at (text, ISO-8601 UTC receiver clock)

peer_consents
├── peer_atsign (text, PK)
├── status (text, default: 'none')
├── last_updated (text)
└── outbound_permitted (boolean, default: true)
```

## Environment Variables

AtNav uses typed, hardcoded constants instead of `.env` files. You can find these in `lib/core/constants.dart`:

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `appNamespace` | Scopes all atKeys specifically to AtNav | `AtNav` |
| `rootDomain` | atDirectory lookup server | `root.atsign.org` |
| `telemetryIntervalSeconds` | Polling rate for GPS updates | `5` |
| `notificationTtlnMs` | Ephemeral notification TTL | `60000` (60s) |
| `trailRetentionHours` | Local SQLite coordinate retention period | `24` |
| `evictionIntervalMinutes`| How often local records are purged | `10` |

## Available Scripts

| Command | Description |
|---------|-------------|
| `flutter pub get` | Install Dart/Flutter packages |
| `dart run build_runner build -d` | Generate Drift database models |
| `flutter run` | Run the application locally |
| `flutter test` | Run the widget test suite |
| `flutter build apk --split-per-abi` | Build a release Android APK |
| `flutter build windows` | Build a release Windows executable |
| `flutter build macos` | Build a release macOS .app package |

## Testing

Run tests across the application by executing:

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage
```
*(Note: Ensure you have built the generated files using `build_runner` prior to testing if modifying database schemas).*

## Deployment

### Android
To build a release APK for Android deployment:
```bash
flutter build apk --split-per-abi
```
The APKs will be located in `build/app/outputs/flutter-apk/`.

### Windows
To build a standalone executable:
```bash
flutter build windows
```
Output will be in `build/windows/runner/Release/`.

### macOS
To build the macOS `.app`:
```bash
flutter build macos
```
Output will be in `build/macos/Build/Products/Release/`. Ensure your provisioning profiles and code signing are configured via Xcode (`macos/Runner.xcworkspace`).

## Troubleshooting

### Android Emulator Issues
**Error:** `No supported devices found with name or id matching 'emulator-5554'`
**Solution:** Ensure your Android emulator is booted up completely before running `flutter run`. Run `flutter emulators` to see available emulators, and launch one with `flutter emulators --launch <id>`.

### Build_Runner Conflicting Outputs
**Error:** `Conflicting outputs were detected...`
**Solution:** Always append the delete flag when regenerating database models:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### macOS Location Permissions Failing
**Error:** Geolocation fails silently on macOS.
**Solution:** Ensure the app is built with the updated entitlements. Check `macos/Runner/DebugProfile.entitlements` to ensure `com.apple.security.personal-information.location` is set to `<true/>`.

### Overflow Exceptions on Onboarding
**Error:** Yellow/black tape pixel overflows on the onboarding screen on small window resizes.
**Solution:** The main panel is wrapped in a `SingleChildScrollView` to fix constraint overflows on mobile and small-desktop sizes.
