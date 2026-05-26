# Spektra

A macOS RTL-SDR spectrum analyzer and radio receiver — explore the radio spectrum around you in real time.

## What it does

Spektra turns a $30 RTL-SDR USB dongle into a full-featured spectrum analyzer and audio demodulator:

- **Spectrum analysis** — Live FFT-based waterfall display with zoom, peak detection, and signal identification
- **Audio demodulation** — Listen to FM, AM, USB, and LSB signals in real time with squelch and volume controls
- **Signal classification** — Automatically identifies FM broadcasts, narrowband FM, AM, digital, pager, ADS-B, and weather radio signals
- **Frequency presets** — Quick-tune to FM radio, NOAA weather, aircraft ADS-B, marine VHF, amateur radio bands, and more

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+
- RTL-SDR dongle (RTL2832U-based)
- librtlsdr: `brew install librtlsdr`

---

## Getting started

```bash
git clone git@github.com:subversivesoftwareorg/spektra.git
cd spektra
open Spektra.xcodeproj
```

Build and run. Plug in your RTL-SDR dongle and start exploring.

---

## Architecture

```
Spektra/
├── App/
│   ├── SpektraApp.swift            # App entry point and menu commands
│   └── AppDelegate.swift          # macOS About panel
├── Resources/
│   └── Assets.xcassets/           # App icon
├── Services/
│   └── SDR/
│       ├── RTLSDRDevice.swift     # Core RTL-SDR device management (librtlsdr + vDSP FFT)
│       ├── SDRAudioEngine.swift   # Real-time FM/AM/SSB audio demodulation
│       └── SignalClassifier.swift # Heuristic signal identification
└── Views/
    ├── MainTabView.swift          # App shell + onboarding
    ├── SettingsView.swift         # Settings window (Cmd+,)
    └── SDR/
        ├── SDRDashboardView.swift # Main SDR interface (tuning, spectrum, signals, audio)
        ├── SDRHelpView.swift      # Comprehensive SDR activity guide
        └── GetSDRView.swift       # SDR hardware purchasing guide
```

---

## SDR activities

See `SDR-GUIDE.md` for detailed instructions on:

- FM Radio, NOAA Weather, Aircraft (ADS-B), Marine VHF, AIS
- Amateur Radio, APRS, Railroad, FRS/GMRS
- ISM bands, Radiosondes, Satellites, Hydrogen Line

---

## Data and privacy

All processing happens on-device. No network requests, no analytics, no telemetry.

---

## Distribution

```bash
./Scripts/create-dmg.sh
```

Builds, signs, embeds librtlsdr, creates a DMG, and notarizes with Apple.
