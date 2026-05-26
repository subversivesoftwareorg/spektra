# Spektra SDR Guide

A practical guide to exploring the radio spectrum with your RTL-SDR dongle and Spektra.

Your NooElec NESDR Mini (R820T tuner) can receive signals from **24 MHz to 1766 MHz**, covering a huge swath of interesting radio activity. This guide walks through the coolest things you can do, organized from easiest to most advanced.

---

## Getting Started

1. Plug in your RTL-SDR dongle
2. Open the **SDR** tab in Spektra
3. The device should auto-detect within a few seconds
4. Click **Start Scanning** to begin viewing the spectrum
5. Use the **Presets** menu to jump to interesting frequencies

### Controls Quick Reference

| Control | What It Does |
|---------|--------------|
| **Frequency** | Center frequency in MHz — type directly or use presets |
| **Step** | Tuning increment for the arrow buttons (1 kHz to 1 MHz) |
| **Gain** | Auto adjusts sensitivity automatically; Manual lets you dial in |
| **Zoom** | 1x shows full 2 MHz bandwidth; 8x zooms to 256 kHz |
| **Demod** | FM for most voice signals, AM for aviation and AM broadcast |
| **Squelch** | Silences audio when signal drops below threshold |

---

## 1. FM Radio (88–108 MHz)

**Difficulty:** Beginner | **Demod:** FM | **Preset:** FM Radio

The classic first SDR experience. Tune to your local FM station and you'll immediately see a wide (~200 kHz) hump on the spectrum and hear music or talk radio.

**How to do it:**
- Select the "FM Radio" preset (100.000 MHz)
- You should see strong signals across the FM band
- Click any detected signal and choose "Listen (FM)"
- Use the step buttons (100 kHz steps work well) to scan across the dial
- Zoom to 2x or 4x to see individual station shapes

**What to look for:** FM broadcast signals are distinctive — they're wide (about 200 kHz) with a characteristic rounded shape. HD Radio stations show a flat digital "shoulder" on each side of the main analog signal.

---

## 2. NOAA Weather Radio (162.400–162.550 MHz)

**Difficulty:** Beginner | **Demod:** FM | **Preset:** NOAA Weather

NOAA broadcasts continuous weather information 24/7 on seven frequencies. These are strong, always-on signals — great for testing your setup.

**Frequencies:**
| Channel | Frequency |
|---------|-----------|
| WX1 | 162.550 MHz |
| WX2 | 162.400 MHz |
| WX3 | 162.475 MHz |
| WX4 | 162.425 MHz |
| WX5 | 162.450 MHz |
| WX6 | 162.500 MHz |
| WX7 | 162.525 MHz |

**How to do it:**
- Select the "NOAA Weather" preset (162.475 MHz)
- You'll see 1–3 active channels depending on your area
- The signal is narrowband FM (~5 kHz) — zoom to 4x to see it clearly
- Click the signal and choose "Listen (FM)"
- You'll hear a synthesized voice reading local weather forecasts

**Pro tip:** If you hear the 1050 Hz alert tone followed by the SAME (Specific Area Message Encoding) data burst, a weather warning is being issued.

---

## 3. Aircraft Communications (118–137 MHz)

**Difficulty:** Beginner | **Demod:** AM | **Best near:** Airports

Aviation uses AM modulation on VHF. If you're within 30 miles of an airport, you'll hear pilots talking to air traffic control.

**Key Frequencies:**
| Service | Frequency |
|---------|-----------|
| Emergency/Guard | 121.500 MHz |
| General aviation | 122.750 MHz (air-to-air) |
| ATIS (recorded weather) | Varies by airport |
| Tower | Varies by airport |
| Approach/Departure | Varies by airport |

**How to do it:**
- Tune to 121.500 MHz (international emergency frequency — usually quiet but always monitored)
- Set demod to **AM** — aviation uses AM, not FM
- Tune to your local airport's tower frequency (search online for "[airport code] frequencies")
- Use 25 kHz steps to scan across the aviation band
- ATIS frequencies give continuous automated weather broadcasts — good for a first listen

**What you'll hear:** Pilots requesting clearances, controllers issuing instructions, altitude and heading assignments. The language is highly structured and fascinating once you learn the terminology.

---

## 4. ADS-B Aircraft Tracking (1090 MHz)

**Difficulty:** Intermediate | **Demod:** AM | **Preset:** Aircraft (ADS-B)

Every commercial aircraft broadcasts its position, altitude, speed, and callsign on 1090 MHz. Spektra can detect these signals on the spectrum, though decoding the data packets requires additional software.

**How to do it:**
- Select the "Aircraft (ADS-B)" preset (1090 MHz)
- Set gain to manual, fairly high (~40 dB)
- You'll see short bursts of digital data appearing as spikes
- The signals are very brief (120 microseconds) so they appear as quick flashes on the spectrum

**What to know:** ADS-B signals are pulsed digital data, so they won't produce useful audio. The spectrum view shows you how busy the airspace is. For full decoding (showing aircraft on a map), tools like `dump1090` work with the same RTL-SDR hardware.

---

## 5. Marine VHF (156–162 MHz)

**Difficulty:** Beginner | **Demod:** FM | **Preset:** Marine VHF | **Best near:** Coasts, lakes, rivers

If you're near any significant body of water, you'll hear boat-to-boat and boat-to-shore communications.

**Key Channels:**
| Channel | Frequency | Use |
|---------|-----------|-----|
| 16 | 156.800 MHz | Distress & calling (always monitored) |
| 9 | 156.450 MHz | Secondary calling |
| 13 | 156.650 MHz | Bridge-to-bridge navigation |
| 22A | 157.100 MHz | Coast Guard announcements |
| 68 | 156.425 MHz | Recreational boaters |
| 72 | 156.625 MHz | Ship-to-ship non-commercial |

**How to do it:**
- Select the "Marine VHF" preset (156.800 MHz, Channel 16)
- Scan up and down with 25 kHz steps
- Listen on Channel 16 for distress calls and hailing
- Channel 13 near ports has bridge-to-bridge traffic

---

## 6. AIS Ship Tracking (161.975 / 162.025 MHz)

**Difficulty:** Intermediate | **Demod:** FM (data) | **Best near:** Coasts, harbors, shipping lanes

AIS (Automatic Identification System) is the maritime equivalent of ADS-B. Every large vessel broadcasts its identity, position, speed, heading, and destination on two dedicated VHF data channels. Coastal stations and other ships use this data for collision avoidance and traffic management.

**Key Frequencies:**
| Channel | Frequency | Use |
|---------|-----------|-----|
| AIS 1 | 161.975 MHz | Primary AIS data channel |
| AIS 2 | 162.025 MHz | Secondary AIS data channel |

**How to do it:**
- Tune to 161.975 MHz or 162.025 MHz
- Set demod to FM — AIS uses 9600-baud GMSK modulation on 25 kHz FM channels
- You'll see periodic narrow bursts appearing every few seconds
- Near busy ports, both channels will be very active with overlapping transmissions
- For full decoding (ship names, positions on a map), pipe the audio to software like `rtl_ais` or AIS decoder tools

**What to know:** AIS is mandated for all vessels over 300 gross tons on international voyages and most commercial ships. Each transmission is a 26.7 ms burst containing the ship's MMSI (unique ID), position, course, speed, and vessel name. Near a busy harbor, you can see dozens of ships broadcasting simultaneously.

**Why it's cool:** You're watching the same data that professional harbor pilots and vessel traffic services use to manage shipping traffic. Combined with a decoder, you can build a real-time map of every ship in range.

---

## 7. Amateur (Ham) Radio

**Difficulty:** Beginner | **Demod:** FM (VHF/UHF) | **Presets:** Amateur 2m, Amateur 70cm

Ham radio operators use a wide variety of frequencies and modes.

**Bands receivable with RTL-SDR:**
| Band | Range | Common Activity |
|------|-------|-----------------|
| 2 meters | 144–148 MHz | Local repeaters, simplex, APRS |
| 70 cm | 420–450 MHz | Repeaters, simplex, digital |
| 23 cm | 1240–1300 MHz | Weak signal, ATV |

**How to do it:**
- Select the "Amateur 2m" preset (146.000 MHz)
- Most activity is on repeater outputs in the 145.1–145.5 MHz and 146.6–147.4 MHz ranges
- Use 10 kHz or 25 kHz steps to scan for activity
- Repeaters transmit on one frequency and listen on another (typically +/- 600 kHz offset)
- The national simplex calling frequency is 146.520 MHz

**What you'll hear:** Casual conversations ("ragchewing"), emergency nets, weather nets, and sometimes special event stations.

---

## 8. APRS Packet Radio (144.390 MHz)

**Difficulty:** Intermediate | **Demod:** FM (data) | **Best with:** Outdoor antenna

APRS (Automatic Packet Reporting System) is a digital ham radio network where stations broadcast their GPS position, weather data, and short messages on a single shared frequency. It's like a decentralized, pre-internet IoT mesh network that's been running since the 1980s.

**Key Frequencies:**
| Region | Frequency |
|--------|-----------|
| North America | 144.390 MHz |
| Europe | 144.800 MHz |
| Australia | 145.175 MHz |
| ISS Digipeater | 145.825 MHz |

**How to do it:**
- Tune to 144.390 MHz (in North America) and set demod to FM
- You'll hear short bursts of data that sound like harsh buzzing/screeching (1200-baud AFSK)
- Transmissions are brief (< 1 second) and appear as narrow spikes on the spectrum
- Near cities, you'll hear packets every few seconds from weather stations, vehicles, and repeater digipeaters
- For full decoding, use software like `direwolf` or `multimon-ng` to decode the AX.25 packets into position reports and messages

**What to know:** APRS was created by Bob Bruninga (WB4APR) and is one of ham radio's most active digital modes. Many hams have APRS trackers in their cars that continuously report position. The ISS also carries an APRS digipeater on 145.825 MHz — during a pass, you can sometimes see packets being relayed through the space station.

---

## 9. FRS, GMRS & MURS Walkie-Talkies

**Difficulty:** Beginner | **Demod:** FM | **Preset:** FRS/GMRS

These are the walkie-talkies you buy at sporting goods stores. You can hear them whenever people are using them nearby.

**FRS/GMRS Channels (462–467 MHz):**
- Channels 1–7: 462.5625–462.7125 MHz (shared FRS/GMRS)
- Channel 8–14: 467.5625–467.7125 MHz (FRS only, low power)
- Channels 15–22: 462.550–462.725 MHz (GMRS)

**MURS (Multi-Use Radio Service):**
- 151.820, 151.880, 151.940, 154.570, 154.600 MHz

**How to do it:**
- Select the "FRS/GMRS" preset
- Scan with 12.5 kHz or 25 kHz steps
- Best at outdoor events, malls, construction sites, theme parks

---

## 10. Railroad Communications (160–162 MHz)

**Difficulty:** Beginner | **Demod:** FM | **Best near:** Rail lines

The Association of American Railroads (AAR) allocates 97 channels between 160.110 and 161.565 MHz. If you're near a rail line, you'll hear dispatchers and train crews.

**Key Frequencies:**
| Railroad | Common Frequency |
|----------|-----------------|
| Amtrak (NE Corridor) | 160.920 MHz (Ch 54) |
| CSX Road | 160.230–161.100 MHz |
| BNSF Road | 160.455–161.415 MHz |
| Union Pacific | 160.515–161.295 MHz |
| Norfolk Southern | 160.290–161.100 MHz |
| End-of-Train devices | 457.9375 MHz |

**How to do it:**
- Tune to 160.500 MHz and scan in 15 kHz steps (AAR channel spacing)
- Listen for dispatchers issuing track warrants and speed restrictions
- The conversations are operational — train numbers, mileposts, track conditions
- Near yards, you'll hear switching crews coordinating car movements

---

## 11. ISM Band Devices (433 MHz / 915 MHz)

**Difficulty:** Intermediate | **Demod:** FM/AM | **Presets:** ISM 433, ISM 915

The ISM (Industrial, Scientific, Medical) bands are unlicensed frequencies used by a huge variety of wireless devices. You won't hear voice, but you'll see fascinating digital bursts.

**What transmits on 433 MHz:**
- Wireless weather stations
- Car key fobs
- Garage door openers
- Wireless doorbells
- Some home security sensors
- Remote thermometers

**What transmits on 915 MHz:**
- Smart utility meters (AMR/AMI)
- LoRa/LoRaWAN IoT devices
- Some cordless phones
- RFID systems
- Baby monitors

**How to do it:**
- Select the "ISM 433 MHz" preset
- Set zoom to 4x or 8x to see individual device transmissions
- You'll see short digital bursts appearing periodically
- Weather stations typically transmit every 30–60 seconds
- Press your car key fob near the antenna to see its signal appear
- Tire pressure monitoring sensors (TPMS) transmit at ~315 MHz or ~433 MHz

**Decoding with rtl_433:** The open-source `rtl_433` tool can decode signals from over 200 device types in the ISM bands — weather stations, tire pressure sensors, doorbell buttons, smoke detectors, and more. It works with the same RTL-SDR hardware and can identify exactly what devices are transmitting around you.

**Security insight:** These signals are often unencrypted. This is one of the reasons Spektra exists — to help you understand what devices around you are broadcasting.

---

## 12. Radiosondes — Weather Balloons (400–406 MHz)

**Difficulty:** Intermediate | **Demod:** FM (data) | **Best near:** NWS launch sites

The National Weather Service launches weather balloons (radiosondes) from approximately 90 stations across the US, twice daily at 00:00 and 12:00 UTC. Each radiosonde transmits temperature, humidity, pressure, wind speed, and GPS position as it ascends to ~30 km altitude.

**Key Frequencies:**
| Type | Frequency |
|------|-----------|
| US radiosondes (typical) | 400–406 MHz |
| Vaisala RS41 (most common) | 402–405 MHz |
| Graw DFM-09 | 400–406 MHz |

**How to do it:**
- Tune to 403 MHz around launch time (roughly 5:15 AM and 5:15 PM local time, but varies)
- Search for your nearest NWS upper-air station to find exact launch times
- You'll see a continuous narrowband signal (~15 kHz wide) that drifts slightly as the balloon rises
- The signal is receivable for 1–2 hours as the balloon ascends to 30+ km before bursting
- Use `radiosonde_auto_rx` or SondeHub tracker to decode telemetry and plot the balloon's flight path in real time

**What to know:** Radiosondes are expendable — they're not recovered after the balloon bursts. They transmit GPS coordinates, so you can even track them down after they land if you want a souvenir (though most end up in remote areas). The Vaisala RS41, used by most US NWS stations, transmits on a frequency printed on its label.

**Why it's cool:** You're tracking a scientific instrument as it rises through the entire atmosphere. The data you decode is the same data that goes into weather forecast models. Some radiosonde hunters use the telemetry to recover the instruments after landing.

---

## 13. Pager Traffic (929–931 MHz)

**Difficulty:** Intermediate | **Demod:** FM

Pagers are still widely used in hospitals, fire departments, and EMS. The 929–931 MHz band is the most active for pager traffic in the US, using POCSAG and FLEX protocols.

**Key Frequencies:**
- 929.6125–931.9375 MHz (scan in 25 kHz steps)
- VHF pagers: 152–158 MHz range

**How to do it:**
- Tune to 929.000 MHz and scan upward in 25 kHz steps
- You'll see narrow, periodic transmissions
- The audio sounds like rapid beeping/chirping (digital data)
- FLEX signals at 6400 baud sound different from slower POCSAG signals

**What to know:** Pager traffic is unencrypted and has been a known privacy concern for decades. Hospitals have been slow to move away from pagers despite the security implications.

---

## 14. Satellites

**Difficulty:** Advanced | **Demod:** FM | **Needs:** Good antenna placement

Several satellites transmit signals receivable with an RTL-SDR, though many benefit from a better antenna than the stock whip.

**NOAA Weather Satellites (APT):**
| Satellite | Frequency |
|-----------|-----------|
| NOAA-15 | 137.620 MHz |
| NOAA-18 | 137.9125 MHz |
| NOAA-19 | 137.100 MHz |

These satellites transmit analog pictures of Earth as they pass overhead (10–15 minute passes, several times daily). With the right software, you can decode these into actual weather satellite images.

**Meteor-M2 (LRPT):**
- 137.100 MHz or 137.900 MHz (varies)
- Digital transmission with higher resolution than NOAA APT

**ISS (International Space Station):**
- 145.825 MHz — APRS packet radio digipeater
- 145.800 MHz — Voice downlink (when astronauts do school contacts)

**Inmarsat (Geostationary):**
- 1537–1545 MHz — Inmarsat STD-C messages (maritime safety, fleet management)
- These are geostationary satellites, so no tracking needed — just point south (in the Northern Hemisphere)
- Signals are weak but continuous; an LNA and patch antenna help significantly
- Decode with `Scytale-C` for STD-C messages or use `Jaero` for Aero channel data

**GOES Weather Imagery:**
- 1694.1 MHz (GOES LRIT) — Low-rate information transmission
- Near the upper limit of the R820T tuner (1766 MHz), so reception is possible but challenging
- Requires: dish antenna (60cm+), LNA (SAWbird+ GOES), and custom feed
- Decode with `goestools` to receive full-resolution weather satellite images directly from geostationary orbit

**How to do it:**
- Check satellite pass times at n2yo.com or use a satellite tracking app
- Tune to the satellite's frequency a few minutes before the pass
- You'll see the signal appear as the satellite rises above the horizon
- The signal gets stronger, then fades as it passes over
- NOAA APT sounds like a rhythmic ticking/whirring — very distinctive

---

## 15. Radio Astronomy — The Hydrogen Line (1420 MHz)

**Difficulty:** Advanced | **Needs:** LNA, directional antenna

Every hydrogen atom in the universe occasionally emits a photon at 1420.405 MHz (21 cm wavelength). With patience and the right setup, you can detect the hydrogen signature of our own galaxy.

**How to do it:**
- This is the most challenging project — the signal is incredibly weak
- You need: a directional antenna (WiFi grid dish works), a low-noise amplifier (LNA like the NooElec SAWbird+ H1), and a bandpass filter
- Tune to 1420.405 MHz with manual gain at maximum
- Point the antenna at the Milky Way (visible galactic plane)
- The hydrogen line appears as a slight bump above the noise floor
- Doppler shifts in the hydrogen line reveal the rotation of our galaxy

**Why it's cool:** This is real radio astronomy. Professional astronomers used this same technique to map the spiral structure of the Milky Way. You're literally detecting the building blocks of stars.

---

## 16. Police/Fire/EMS Scanner (150–174 MHz / 450–470 MHz)

**Difficulty:** Beginner | **Demod:** FM | **Best near:** Any populated area

Many police, fire, and EMS departments still use analog FM radio for dispatch and field communications. These fall in two main bands:

- **VHF** (150–174 MHz) — older, smaller departments, federal agencies
- **UHF** (450–470 MHz) — many city/county agencies

**How to listen:**
1. Select the "Public Safety VHF" preset (155.475 MHz)
2. Scan with 12.5 kHz steps — channels are closely spaced
3. Look up your local frequencies at radioreference.com
4. Try UHF (450–470 MHz) if VHF is quiet — many agencies are there instead

**Note:** Many larger departments have migrated to digital P25 trunked systems (see section 17). You'll see their transmissions on the spectrum but won't be able to demodulate voice in Spektra.

---

## 17. Trunked Radio Systems (851–869 MHz)

**Difficulty:** Intermediate | **Demod:** FM (mostly digital)

Large police, fire, and government agencies often use trunked radio systems on 800 MHz. Unlike conventional radio where each group has a fixed frequency, trunked systems dynamically assign frequencies from a shared pool. You'll see brief digital bursts jumping across the band.

**How to spot them:**
1. Select the "Trunked 800 MHz" preset (860 MHz)
2. Zoom to 2x to see the full band
3. Control channels appear as always-on signals — these manage the trunking
4. Voice channels appear as brief bursts that hop around

**Decoding:** Requires specialized software like trunk-recorder, SDR Trunk, or OP25 to follow the trunking protocol and extract audio.

---

## 18. Surveillance Sweep (900 MHz / 1.2 GHz)

**Difficulty:** Intermediate | **What to look for:** Persistent wideband signals

Analog wireless cameras transmit continuous video on two bands within RTL-SDR range:
- **900 MHz** (900–930 MHz) — older wireless cameras, baby monitors
- **1.2 GHz** (1240–1300 MHz) — some wireless cameras

A persistent wideband signal (>50 kHz wide) in these bands in a hotel room, AirBnB, or office could indicate a hidden camera. Unlike IoT devices that transmit brief bursts, cameras transmit continuously.

**How to sweep:**
1. Select the "Surveillance 900" preset (910 MHz)
2. Look for wide, continuous humps (not brief digital bursts)
3. Walk around the room — signal strength increases near the camera
4. Also check 1240–1300 MHz
5. Note: Modern IP cameras use WiFi (2.4/5 GHz) and won't appear here

---

## 19. GPS Jammer Detection (1575 MHz)

**Difficulty:** Intermediate | **What to look for:** Wideband noise dome

GPS signals from satellites are incredibly weak — well below the noise floor of an RTL-SDR. Under normal conditions, you'll see nothing but flat noise at 1575.42 MHz. Any strong wideband signal here is anomalous.

GPS jammers produce a characteristic wide noise dome centered on 1575 MHz. They're used by vehicle thieves to defeat tracking and by some commercial drivers to circumvent fleet monitoring. Detecting one near you could explain GPS issues on your phone or in your car.

**How to check:**
1. Select the "GPS L1" preset (1575.42 MHz)
2. Normal: flat noise, no visible signal
3. Anomalous: a wide hump or spike — something is deliberately interfering

---

## 20. Drone Detection (433 MHz / 900 MHz)

**Difficulty:** Advanced | **What to look for:** Bursty digital signals

Most consumer drones (DJI, etc.) use 2.4 GHz and 5.8 GHz for control and video — **out of RTL-SDR range**. However, some systems are detectable:

- **433 MHz** — telemetry links on some drone platforms
- **900 MHz** — long-range control systems like TBS Crossfire and ExpressLRS
- **1.2–1.3 GHz** — analog FPV video downlinks

Drone control links typically appear as periodic digital bursts — wider bandwidth and more regular than typical IoT devices. A 900 MHz link sending continuous data at ~500 kHz bandwidth near you, where there shouldn't be one, could indicate a drone.

**Limitations:** This is probabilistic, not definitive. The 900 MHz ISM band has lots of legitimate traffic. Don't rely solely on SDR for drone detection.

---

## 21. Wireless Microphones (470–698 MHz)

**Difficulty:** Intermediate | **Demod:** FM

Wireless microphones operate in the former TV broadcast band. Normal at concerts, churches, theaters, and conference venues — unexpected in a private office or home.

**How to scan:**
1. Tune to 550 MHz and scan with 100 kHz steps
2. Wireless mics appear as narrow FM signals
3. Active ones carry continuous audio
4. Listen with FM demod to hear what the microphone is picking up

---

## Tips & Best Practices

### Improving Reception
- **Antenna matters:** The stock whip antenna works for strong signals. For weaker signals, a dipole cut for your target frequency makes a huge difference.
- **Gain settings:** Start with Auto. If signals are clipping (flat tops on the spectrum), reduce gain. If you can't see weak signals, increase gain.
- **Location:** Near a window or outdoors is dramatically better than deep inside a building. RF doesn't pass through metal well.

### Understanding the Spectrum Display
- **Y-axis (dB):** Signal power. Noise floor is typically -40 to -60 dB. Strong signals peak at -10 to 0 dB.
- **X-axis:** Frequency, centered on your tuned frequency.
- **Bandwidth:** The width of a signal indicates its type. FM broadcast is ~200 kHz wide. Voice channels are 12.5–25 kHz. Digital bursts are often very narrow.

### Signal Identification
Spektra automatically classifies detected signals by analyzing:
- **Frequency band** — what services are allocated to this part of the spectrum
- **Bandwidth** — how wide the signal is (measured at -6 dB from peak)
- **Spectral shape** — flat-topped (digital), peaked (carrier), or irregular

### Legal Notes
- **Receiving is legal.** In the United States, it is legal to receive any radio signal. The Communications Act protects the right to listen.
- **Do not transmit.** RTL-SDR devices are receive-only, but be aware that transmitting on most frequencies requires a license.
- **Some content restrictions apply.** While receiving is legal, certain laws restrict the use of intercepted communications (e.g., cellular phone calls, which are above the R820T's range anyway).

---

## Frequency Quick Reference

| What | Frequency | Demod | When/Where |
|------|-----------|-------|------------|
| FM Radio | 88–108 MHz | FM | Always, everywhere |
| Air Traffic Control | 118–137 MHz | AM | Near airports |
| NOAA Satellites | 137.1–137.9 MHz | FM | During overhead passes |
| APRS | 144.390 MHz | FM | Amateur radio digital |
| Amateur 2m | 144–148 MHz | FM | Varies |
| MURS | 151.8–154.6 MHz | FM | Business, farm, security |
| Public Safety VHF | 150–174 MHz | FM | Police, fire, EMS |
| Marine VHF | 156–162 MHz | FM | Near water |
| Railroad | 160.1–161.6 MHz | FM | Near rail lines |
| AIS Ships | 161.975/162.025 MHz | FM | Near water |
| NOAA Weather | 162.4–162.55 MHz | FM | Always, everywhere |
| Radiosondes | 400–406 MHz | FM | Twice daily launches |
| ISM 433 MHz | 433.05–434.79 MHz | - | IoT, key fobs, drones |
| Amateur 70cm | 420–450 MHz | FM | Varies |
| Public Safety UHF | 450–470 MHz | FM | Police, fire, EMS |
| FRS/GMRS | 462–467 MHz | FM | Outdoor events |
| Wireless Mics | 470–698 MHz | FM | Events, venues |
| Trunked 800 MHz | 851–869 MHz | FM | Police, fire (digital) |
| Wireless Cameras | 900–930 MHz | - | Surveillance |
| ISM 915 MHz | 902–928 MHz | - | IoT, LoRa, smart meters |
| Pagers | 929–931 MHz | - | Hospitals, fire/EMS |
| ADS-B | 1090 MHz | AM | Near flight paths |
| 1.2 GHz Cameras | 1240–1300 MHz | - | Surveillance |
| Hydrogen Line | 1420.4 MHz | - | Milky Way visible |
| Inmarsat | 1537–1545 MHz | - | Geostationary (south) |
| GPS L1 | 1575.42 MHz | - | Jammer detection |
| GOES LRIT | 1694.1 MHz | - | Geostationary (south) |
