import SwiftUI
import MapKit

struct AircraftMapView: View {
    @Environment(RTLSDRDevice.self) private var sdr
    @State private var selectedAircraft: ADSBDecoder.Aircraft?
    @State private var mapPosition = MapCameraPosition.automatic

    private var trackedAircraft: [ADSBDecoder.Aircraft] {
        sdr.adsbDecoder.aircraft.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        NavigationStack {
            HSplitView {
                mapContent
                    .frame(minWidth: 400)
                aircraftSidebar
                    .frame(width: 320)
            }
            .navigationTitle("Aircraft Tracker")
            .toolbar {
                ToolbarItem {
                    statusIndicator
                }
                ToolbarItem {
                    Button {
                        mapPosition = .automatic
                    } label: {
                        Label("Fit All", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .disabled(trackedAircraft.isEmpty)
                }
            }
            .onAppear { startTracking() }
        }
    }

    // MARK: - Map

    private var mapContent: some View {
        Map(position: $mapPosition, selection: $selectedAircraft) {
            ForEach(trackedAircraft) { ac in
                Annotation(
                    ac.callsign.isEmpty ? ac.icaoHex : ac.callsign,
                    coordinate: CLLocationCoordinate2D(
                        latitude: ac.latitude!,
                        longitude: ac.longitude!
                    ),
                    anchor: .center
                ) {
                    AircraftMarker(aircraft: ac, isSelected: selectedAircraft?.icao == ac.icao)
                        .onTapGesture { selectedAircraft = ac }
                }
                .tag(ac)
            }
        }
        .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
        .mapControls {
            MapCompass()
            MapScaleView()
            MapZoomStepper()
        }
    }

    // MARK: - Sidebar

    private var aircraftSidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()

            if sdr.adsbDecoder.aircraft.isEmpty {
                sidebarEmpty
            } else {
                sidebarList
            }

            Divider()
            sidebarStats
        }
        .background(.background)
    }

    private var sidebarHeader: some View {
        HStack {
            Label("Aircraft", systemImage: "airplane")
                .font(.headline)
            Spacer()
            Text("\(trackedAircraft.count) on map")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var sidebarEmpty: some View {
        VStack(spacing: 12) {
            Spacer()
            if sdr.adsbDecoder.isActive {
                ProgressView().controlSize(.small)
                Text("Listening on 1090 MHz...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Aircraft will appear as ADS-B\nmessages are received.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "airplane.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Decoder not active")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var sidebarList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sdr.adsbDecoder.aircraft) { ac in
                    AircraftSidebarRow(
                        aircraft: ac,
                        isSelected: selectedAircraft?.icao == ac.icao
                    )
                    .onTapGesture {
                        selectedAircraft = ac
                        if let lat = ac.latitude, let lon = ac.longitude {
                            withAnimation {
                                mapPosition = .camera(MapCamera(
                                    centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                    distance: 50000
                                ))
                            }
                        }
                    }
                    Divider().padding(.leading, 40)
                }
            }
        }
    }

    private var sidebarStats: some View {
        HStack(spacing: 16) {
            Label("\(sdr.adsbDecoder.messageCount)", systemImage: "envelope.fill")
            if sdr.adsbDecoder.crcErrors > 0 {
                Label("\(sdr.adsbDecoder.crcErrors) err", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Spacer()
            Button("Clear") {
                sdr.adsbDecoder.clearAircraft()
                selectedAircraft = nil
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(sdr.adsbDecoder.isActive ? .green : .gray)
                .frame(width: 8, height: 8)
            Text(sdr.adsbDecoder.isActive ? "Live · 1090 MHz" : "Inactive")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Auto-Start

    private func startTracking() {
        guard sdr.connectionState == .connected else { return }
        if !sdr.adsbDecoder.isActive {
            sdr.stopSweep()
            sdr.stopListening()
            sdr.centerFrequency = 1_090_000_000
            if !sdr.isStreaming { sdr.startStreaming() }
            sdr.adsbDecoder.isActive = true
        }
    }
}

// MARK: - Aircraft Marker

private struct AircraftMarker: View {
    let aircraft: ADSBDecoder.Aircraft
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "airplane")
                .font(.system(size: isSelected ? 18 : 14, weight: .bold))
                .foregroundStyle(isSelected ? .white : altitudeColor)
                .rotationEffect(.degrees(Double(aircraft.heading ?? 0)))
                .padding(isSelected ? 6 : 4)
                .background(
                    isSelected ? Color.blue : Color.black.opacity(0.6),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? .white : .clear, lineWidth: 2)
                )

            if isSelected {
                detailCallout
            }
        }
    }

    private var detailCallout: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !aircraft.callsign.isEmpty {
                Text(aircraft.callsign)
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
            }
            Text(aircraft.icaoHex)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            if let alt = aircraft.altitude {
                Text("\(alt) ft")
                    .font(.system(.caption2, design: .monospaced))
            }
            if let spd = aircraft.groundSpeed {
                Text("\(spd) kt")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private var altitudeColor: Color {
        guard let alt = aircraft.altitude else { return .cyan }
        if alt > 30000 { return .blue }
        if alt > 15000 { return .cyan }
        if alt > 5000 { return .green }
        return .orange
    }
}

// MARK: - Sidebar Row

private struct AircraftSidebarRow: View {
    let aircraft: ADSBDecoder.Aircraft
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.caption)
                .foregroundStyle(aircraft.latitude != nil ? .blue : .gray)
                .rotationEffect(.degrees(Double(aircraft.heading ?? 0)))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(aircraft.callsign.isEmpty ? aircraft.icaoHex : aircraft.callsign)
                        .font(.system(.callout, design: .monospaced, weight: .medium))

                    if !aircraft.callsign.isEmpty {
                        Text(aircraft.icaoHex)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 8) {
                    if let alt = aircraft.altitude {
                        Text("\(alt) ft")
                    }
                    if let spd = aircraft.groundSpeed {
                        Text("\(spd) kt")
                    }
                    if let hdg = aircraft.heading {
                        Text("\(hdg)\u{00B0}")
                    }
                    if let vr = aircraft.verticalRate, vr != 0 {
                        Text("\(vr > 0 ? "+" : "")\(vr) fpm")
                            .foregroundStyle(vr > 0 ? .green : .orange)
                    }
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if aircraft.latitude == nil {
                Text("No pos")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : .clear)
        .contentShape(Rectangle())
    }
}
