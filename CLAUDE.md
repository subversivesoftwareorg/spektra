# Spektra

macOS RTL-SDR spectrum analyzer and radio receiver by Subversive Software.

## Quick Start

```bash
brew install librtlsdr
open Spektra.xcodeproj
# Build and run (Cmd+R), plug in RTL-SDR dongle
```

## Tech Stack

- **Language**: Swift (100%), SwiftUI with `@Observable` macro
- **Platform**: macOS 14.0+ (Sonoma), arm64
- **Build**: Xcode 15+ project (no SPM/CocoaPods)
- **SDR**: librtlsdr via Homebrew, bridged through `CRtlSdr/module.modulemap`
- **DSP**: Apple Accelerate (`vDSP`) for FFT, windowing, vector math
- **Audio**: AVFoundation (`AVAudioEngine` + `AVAudioSourceNode`)
- **Bundle ID**: `com.subversivesoftware.Spektra`

## Architecture

```
Spektra/
├── App/
│   ├── SpektraApp.swift            # @main entry, window/menu setup
│   └── AppDelegate.swift           # About panel
├── Services/SDR/
│   ├── ADSBDecoder.swift           # ADS-B 1090 MHz decoder: PPM→CRC→aircraft tracking
│   ├── POCSAGDecoder.swift         # POCSAG pager decoder: FSK→clock recovery→message parsing
│   ├── ProtocolScanner.swift        # Sweep-dwell-decode state machine for auto protocol discovery
│   ├── RTLSDRDevice.swift          # Device mgmt, FFT pipeline, peak detection, presets
│   ├── SDRAudioEngine.swift        # FM/AM/SSB demod, decimation, ring buffer playback
│   └── SignalClassifier.swift      # Heuristic signal identification (16 types)
├── Views/
│   ├── MainTabView.swift           # App shell + onboarding
│   ├── SettingsView.swift          # Cmd+, settings
│   └── SDR/
│       ├── AircraftMapView.swift     # ADS-B map: auto-tune 1090 MHz, MapKit + sidebar
│       ├── DecodersView.swift       # Protocol decoder UI + compact Expert Tuner preview
│       ├── ProtocolScannerView.swift # Auto sweep-dwell-decode UI with activity log
│       ├── SDRDashboardView.swift  # Expert Tuner: tuning, spectrum, signals, audio
│       ├── SignalFinderView.swift   # Simplified UI: band sweep, auto-detect signals
│       ├── SignalLogView.swift      # Session inventory: all signals ever detected
│       ├── SDRHelpView.swift       # 21-activity SDR guide
│       └── GetSDRView.swift        # Hardware purchasing guide
└── Resources/Assets.xcassets/      # App icons
CRtlSdr/module.modulemap           # C bridge to librtlsdr
Scripts/create-dmg.sh               # Build, sign, embed dylibs, DMG, notarize
```

## Key Concepts

**RTLSDRDevice** is the central `@Observable` model. It manages device polling, IQ streaming via `rtlsdr_read_async`, FFT processing (2048-point via vDSP), peak detection, and signal classification. The dashboard view observes it directly.

**Signal pipeline**: Raw IQ → Hann window → FFT → magnitude → dB → FFT shift → EMA smoothing → peak detection → SignalClassifier → DetectedSignal

**Audio pipeline**: Raw IQ → FM/AM/SSB demod → box-filter decimation (2.048 MHz → 48 kHz) → ring buffer → AVAudioSourceNode

**POCSAG pipeline**: Raw IQ → FM discriminator → decimate (2.048 MHz → 48.8 kHz) → zero-crossing clock recovery → bit slicing → sync word detection → codeword parsing → address/message assembly → character decode (7-bit alpha or BCD numeric)

**ADS-B pipeline**: Raw IQ → magnitude² → preamble correlation (8µs pattern) → PPM bit extraction → CRC-24 validation → DF17 message parsing → CPR position decode → aircraft state tracking (auto-prunes after 60s)

**Presets**: 16 hardcoded `FrequencyPreset` structs in RTLSDRDevice (FM, ATC, Ham, NOAA, ADS-B, etc.)

**Scan Bands**: 8 `ScanBand` structs defining sweepable frequency ranges (FM, Aviation, VHF, UHF, 800/900 MHz, ADS-B, NOAA). The sweep engine steps through each band in 2 MHz increments, dwelling 8 FFT frames per step, then deduplicates signals by proximity.

**SignalClassifier**: Frequency-band heuristics cascade — measures bandwidth at -6 dB and spectral flatness, then matches against 23 ordered rules to produce a type + confidence score.

**ProtocolScanner**: Sweep-dwell-decode state machine. Sweeps like Signal Finder, but when a decodable signal is classified (ADS-B or pager), pauses the sweep, activates the appropriate decoder for 15 seconds, logs results, then resumes. Uses a 2-minute cooldown per frequency to avoid re-dwelling.

**Navigation**: Tab-based — Signal Finder (scan), Protocol Scanner (auto decode), Signal Log (session inventory), Expert Tuner (manual tuning with compact decoder preview), Decoders (protocol decode for ADS-B and POCSAG), Aircraft (live map with auto-tune to 1090 MHz).

## Development Notes

- The app runs outside the sandbox (`Spektra.entitlements`: sandbox=NO) because USB device access requires it
- Sample rate is fixed at 2.048 MHz
- FFT smoothing uses alpha=0.3 exponential moving average
- Peak detection threshold is -30 dB, 5-bin local maximum test, max 8 peaks
- The C callback bridge uses `Unmanaged<RTLSDRDevice>` to pass `self` through the C function pointer
- SSB demod is approximate (I±Q without Hilbert filter)

## Distribution

```bash
./Scripts/create-dmg.sh
```

Auto-increments build number, builds release, embeds librtlsdr + libusb dylibs, codesigns, creates DMG, notarizes with Apple. Signing team: `84CC987JU3`.
