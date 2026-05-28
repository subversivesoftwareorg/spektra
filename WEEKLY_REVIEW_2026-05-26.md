# Weekly Project Review — Spektra — 2026-05-26

## Project Summary
Spektra is a macOS RTL-SDR spectrum analyzer and radio receiver. It turns an RTL-SDR USB dongle into a live FFT-based waterfall display with audio demodulation (FM, AM, USB, LSB), automatic signal classification, and frequency presets for FM radio, NOAA weather, aircraft ADS-B, marine VHF, and amateur radio. Built as an Xcode project with Swift/SwiftUI, depends on system librtlsdr (via Homebrew). Targets macOS 14+.

## Top Action Items
1. **[HIGH] RTL-SDR Blog V4 end-of-line** — The popular RTL-SDR Blog V4 dongle has reached end-of-line due to exhaustion of Rafael R828D chip stockpiles. Consider testing with alternative hardware and updating documentation.
2. **[MODERATE] Test with librtlsdr updates** — Ensure compatibility with the latest Homebrew version of librtlsdr.
3. **[LOW] Consider xSDR compatibility** — The crowdfunded xSDR (M.2 form factor SDR, $549, shipping July 2026) may become a popular alternative. Consider supporting its API.

## Security & Vulnerabilities

No managed dependencies to audit. The project depends on:
- librtlsdr (system library via Homebrew) — Check Homebrew for any recent advisories.
- Apple frameworks (Accelerate/vDSP for FFT, AVFoundation for audio).

The use of system C libraries (librtlsdr) carries inherent risk from buffer overflows in SDR data processing, but no known CVEs were found.

## Dependency Version Drift

| Package | Status | Notes |
|---------|--------|-------|
| librtlsdr | System (Homebrew) | Run `brew upgrade librtlsdr` to ensure latest |
| Xcode project | 15+ | Consider migrating to Swift Package Manager for better dependency management |

## Domain News & Releases (past 7 days)
- **RTL-SDR Blog V4 end-of-line** — No more production possible due to Rafael R828D chip shortage. [Source](https://www.rtl-sdr.com/rtl-sdr-blog-v4-end-of-line/)
- **OpenWXSDR released (May 2026)** — Open-source Python framework for automated radiosonde ground stations using RTL-SDR. [Source](https://www.rtl-sdr.com/)
- **xSDR crowdfunded** — Compact M.2 form-factor SDR at $549, shipping July 2026. [Source](https://www.rtl-sdr.com/)
- **Web-Spectrum** — A web-based spectrum analyzer with RTL-SDR support emerged in early 2026.

## Architectural & Tech-Trend Opportunities
- **Support multiple SDR hardware** — With RTL-SDR V4 going end-of-line, consider abstracting the hardware layer to support Airspy, HackRF, or the upcoming xSDR alongside RTL-SDR dongles.
- **SoapySDR abstraction layer** — SoapySDR provides a vendor-neutral SDR API that would enable multi-hardware support with a single integration point.
- **Web-based spectrum sharing** — Consider a mode that streams spectrum data to a local web UI, enabling remote monitoring from other devices on the LAN.
- **ADS-B decoder integration** — The signal classifier identifies ADS-B; consider integrating dump1090 decoding for plane tracking visualization.

## Notes & Limitations
- No package manager lockfile to audit — the project uses Xcode project format with system library dependency.
- librtlsdr version could not be checked (Homebrew not available in sandbox).
- The CRtlSdr directory suggests C bridging headers for librtlsdr — these should be reviewed for unsafe memory patterns.
