# AtNav — System Architecture Specification

## AI Architect Blueprint

---

## 1. System Topology

AtNav is a **decentralized, peer-to-peer** desktop location sharing application. There is **no central server** storing user coordinates. Each participant owns their own cryptographic identity (an atSign) and a dedicated personal micro-server (atServer).

```
┌───────────────────────────────┐         ┌───────────────────────────────┐
│  AtNav Desktop @ @alice     │         │  AtNav Desktop @ @bob       │
│  ┌─────────────────────────┐  │         │  ┌─────────────────────────┐  │
│  │ TelemetryStreamer        │  │         │  │ TelemetryListener        │  │
│  │ • GPS Poll (5s)          │  │         │  │ • Monitor Socket         │  │
│  │ • JSON Package           │  │         │  │ • SDK Auto-Decrypt       │  │
│  │ • AES-256 Encrypt (SDK)  │  │         │  │ • Parse JSON             │  │
│  └──────────┬──────────────┘  │         │  └──────────┬──────────────┘  │
│             │ notify()         │         │             │                  │
│  ┌──────────▼──────────────┐  │         │  ┌──────────▼──────────────┐  │
│  │ atClient                 │  │         │  │ SQLite (Drift)          │  │
│  │ NotificationService      │  │         │  │ Local Coordinate Store  │  │
│  └──────────┬──────────────┘  │         │  └──────────┬──────────────┘  │
└─────────────┼─────────────────┘         └─────────────┼─────────────────┘
              │                                          │
              │ TLS                                     │ Reactive Stream
              ▼                                          ▼
┌─────────────────────────┐                ┌──────────────────────────────┐
│  atServer @alice         │──────────────▶│  atServer @bob               │
│  Encrypted Blob Storage  │  Cross-atSign │  Encrypted Blob Storage      │
│  (opaque ciphertexts)    │  TLS notify   │  (opaque ciphertexts)        │
└─────────────┬───────────┘                └──────────────────────────────┘
              │
              ▼
┌─────────────────────────┐
│  atDirectory             │
│  root.atsign.org:64      │
│  atSign → host:port map  │
└─────────────────────────┘
```

## 2. Cryptographic Data-Flow Matrix

### Sender Side (@alice → @bob)

| Step | Component | Operation |
|------|-----------|-----------|
| 1 | `Geolocator` | Polls device GPS → `Position(lat, lng, accuracy)` |
| 2 | `TelemetryStreamer` | Packages `{lat, lng, ts, acc}` as compact JSON |
| 3 | `at_client SDK` | Fetches/generates shared AES-256 symmetric key for `@bob` |
| 4 | `at_client SDK` | Generates random IV nonce (16 bytes) |
| 5 | `at_client SDK` | AES-256-CTR encrypts JSON value → ciphertext |
| 6 | `at_client SDK` | RSA-2048 encrypts shared key → `sharedKeyEnc` using `public:publickey@bob` |
| 7 | `at_client SDK` | Sends `notify:@bob:location.AtNav@alice <base64(ciphertext)>` with `ttln=60000` |

### Wire Transmission

| Field | Content |
|-------|---------|
| Key | `@bob:location.AtNav@alice` |
| Value | `base64(AES-256-CTR(json_payload, shared_key, iv))` |
| `metadata.sharedKeyEnc` | `base64(RSA-2048(shared_key, bob_public_key))` |
| `metadata.ivNonce` | `base64(iv_nonce)` |
| `metadata.ttln` | `60000` (60 seconds — ephemeral, bypasses commit log) |
| `metadata.isEncrypted` | `true` |

### Receiver Side (@bob)

| Step | Component | Operation |
|------|-----------|-----------|
| 1 | `monitor:.AtNav` | Persistent socket receives notification JSON |
| 2 | `at_client SDK` | Extracts `sharedKeyEnc` from metadata |
| 3 | `at_client SDK` | RSA-2048 decrypts shared key using `bob.encryptionPrivateKey` |
| 4 | `at_client SDK` | AES-256-CTR decrypts value using shared key + `ivNonce` |
| 5 | `TelemetryListener` | Parses plaintext JSON → `TelemetryPoint` |
| 6 | `LocalDb` | `INSERT INTO coordinates(peer_atsign, lat, lng, ts, received_at)` |
| 7 | `MapScreen` | Reactive stream binding updates pin position and trail |

### Zero-Knowledge Guarantee

The **atServer never possesses decryption keys**. At every point in the transmission:
- The atServer stores only **opaque ciphertexts**
- Metadata fields (`sharedKeyEnc`, `ivNonce`) are themselves encrypted artifacts
- Server-side filtering, analytics, or aggregation of location values is **architecturally impossible**

## 3. Local Telemetry Engine

### SQLite Schema (Drift)

```sql
CREATE TABLE coordinates (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  peer_atsign   TEXT    NOT NULL,
  latitude      REAL    NOT NULL,
  longitude     REAL    NOT NULL,
  accuracy      REAL,
  timestamp     TEXT    NOT NULL,  -- ISO-8601 UTC (sender's device clock)
  received_at   TEXT    NOT NULL   -- ISO-8601 UTC (receiver's local clock)
);

CREATE INDEX idx_peer_ts ON coordinates(peer_atsign, timestamp DESC);
```

### Automatic Eviction Loop

| Parameter | Value | Description |
|-----------|-------|-------------|
| `trailRetentionHours` | 24 | Maximum age for cached coordinates |
| `evictionIntervalMinutes` | 10 | How often the eviction sweep runs |
| `maxTrailPoints` | 500 | Maximum polyline trail points per peer |

The eviction loop runs as a `Timer.periodic` on the UI isolate (lightweight — a single `DELETE WHERE timestamp < cutoff` query). It runs immediately on startup and then every 10 minutes.

### Query Interface

| Method | Return Type | Description |
|--------|-------------|-------------|
| `insertCoordinate(TelemetryPoint)` | `Future<int>` | Non-blocking insert |
| `watchLatestByPeer()` | `Stream<Map<String, TelemetryPoint>>` | Reactive latest position per peer |
| `getTrail(peer, {limit})` | `Future<List<TelemetryPoint>>` | Polyline history (newest first) |
| `getTimeRange(peer, from, to)` | `Future<List<TelemetryPoint>>` | Time-bucketed range query |
| `watchTrail(peer, {limit})` | `Stream<List<TelemetryPoint>>` | Reactive trail updates |
| `evictExpired()` | `Future<int>` | Purge records older than retention |
| `getTrackedPeers()` | `Future<List<String>>` | Distinct peer atSign list |

## 4. Notification Lifecycle

### Why `ttln` (Time-To-Live Notification)?

Standard `update` verb calls write to the atServer's **append-only commit log**. For high-frequency telemetry (coordinates every 5 seconds), this would create:
- `12 writes/minute × 60 minutes × 24 hours = 17,280 commit log entries per day per peer`

This would bloat the commit log, slow sync operations, and violate the atServer's designed workload.

By using `notify` with `ttln=60000`:
- The notification is delivered to the recipient's monitor stream
- It is **not written to the commit log**
- It expires from server memory after 60 seconds
- The recipient persists it locally in SQLite — the only permanent storage

### Notification State Machine

```
SENDER                      atServer @alice              atServer @bob                RECEIVER
  │                              │                            │                          │
  │─── notify(ttln=60000) ──────▶│                            │                          │
  │                              │──── cross-atSign TLS ────▶│                          │
  │                              │                            │── monitor push ─────────▶│
  │                              │                            │                          │── decrypt
  │                              │                            │                          │── parse JSON
  │                              │                            │                          │── INSERT SQLite
  │                              │                            │                          │── emit Stream
  │                              │                            │                          │── update MapPin
  │                              │                            │                          │
  │                              │◄── expires after 60s ─────│                          │
```

## 5. Authentication Flow (PKAM)

```
USER                    AtNav App                 atServer @alice          atDirectory
  │                         │                            │                      │
  │── select .atKeys ─────▶│                            │                      │
  │── enter @alice ────────▶│                            │                      │
  │                         │── lookup @alice ──────────────────────────────────▶│
  │                         │◄── host:port ────────────────────────────────────│
  │                         │── TLS connect ────────────▶│                      │
  │                         │── from:@alice ────────────▶│                      │
  │                         │◄── challenge UUID ────────│                      │
  │                         │── pkam:<signature> ───────▶│                      │
  │                         │   (signed with PKAM        │                      │
  │                         │    private key from         │                      │
  │                         │    .atKeys file)            │                      │
  │                         │◄── @alice@ (auth prompt) ──│                      │
  │◄── AUTHENTICATED ──────│                            │                      │
```

## 6. Design System: Clean Orange & White

### Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `bgPrimary` | `#FFFFFF` | Pure white background |
| `bgSurface` | `#F9F9F9` | Card and panel surfaces |
| `bgElevated` | `#F0F0F0` | Elevated compartment backgrounds |
| `fgPrimary` | `#1A1A1A` | Dark primary text |
| `fgSecondary` | `#666666` | Dimmed metadata and labels |
| `fgTertiary` | `#999999` | Muted timestamps and supplementary info |
| `accentOrange` | `#FF5A00` | Atsign Orange — primary accent, active pins, alerts, dividers |
| `terminalGreen` | `#34C759` | Live connection status indicator only |
| `borderColor` | `#E0E0E0` | Compartment edges and structural dividers |

### Typography

| Scale | Font | Size | Tracking | Usage |
|-------|------|------|----------|-------|
| Macro | Inter (700) | 18-36px | -0.02em | Section headers, app title |
| Micro | Inter (400) | 9-14px | default | All data readouts, coordinates |
| Label | Inter (600) | 8-10px | +0.05em | Metadata labels, section titles |

### Layout Rules

- **Responsive breakpoint**: `800px` — widths ≥ 800px use the desktop layout; below uses mobile layout
- **Desktop**: 30% persistent peer sidebar + 70% full-bleed map, top status bar, bottom telemetry ticker
- **Mobile**: Full-screen map, draggable bottom sheet for peer management, mobile AppBar
- Rounded corners (`border-radius: 6-8px`) for panels, inputs, and buttons
- `1px solid` borders using `borderColor` for compartmentalization
- Thick `2px` Atsign Orange horizontal rules between primary zones
- Section labels styled as uppercase monospaced text (no ASCII brackets)
