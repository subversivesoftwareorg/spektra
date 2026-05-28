# Spektra Roadmap

## In Progress

### Protocol Decoders
- **POCSAG Pager Decoding** — Decode alphanumeric/numeric pager messages from narrowband FM signals (~152-158 MHz). FSK demod → clock recovery → POCSAG frame parsing.
- **ADS-B Aircraft Tracking** — Decode 1090 MHz Extended Squitter messages to extract aircraft ICAO address, callsign, position (CPR), altitude, velocity, heading. Display tracked aircraft in a dedicated view.

## Future

### Additional Decoders
- **ACARS** — Decode aircraft text messages (129.125 MHz, 131.550 MHz). AM-modulated MSK data carrying operational messages.
- **AIS** — Decode marine vessel transponder data (161.975/162.025 MHz). GMSK modulation, HDLC framing. Ship name, position, course, speed.
- **NOAA APT** — Decode weather satellite imagery from NOAA 15/18/19 (~137 MHz). AM-modulated image lines, requires pass prediction and Doppler correction.
- **DMR/P25 Digital Voice** — Decode trunked digital radio voice. Requires AMBE codec (patent-encumbered), may need external vocoder.
- **SAME/EAS** — Decode Specific Area Message Encoding from NOAA Weather Radio (162 MHz). AFSK 520.83 baud, emergency alert metadata.

### Features
- **Waterfall Display** — Time-scrolling spectrogram showing signal history as a color-mapped waterfall plot alongside the spectrum view.
- **Recording** — Record raw IQ samples to file for offline analysis. Also record decoded audio to WAV.
- **Signal Bookmarks** — Save frequencies of interest with notes, beyond the session-scoped signal log.
- **Multi-Dongle** — Support multiple RTL-SDR dongles simultaneously for monitoring separate bands.
- **Frequency Database** — Integrate RadioReference or similar frequency database for automatic signal identification by geographic region.
- **Export** — Export signal log and decoded data to CSV/JSON.
