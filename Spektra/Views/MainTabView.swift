import SwiftUI

struct MainTabView: View {
    @State private var sdrDevice = RTLSDRDevice()
    @State private var showOnboarding = false

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        SDRDashboardView()
            .environment(sdrDevice)
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            .onAppear {
                if !hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
    }
}

// MARK: - Onboarding
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, description: String)] = [
        ("waveform", "Welcome to Spektra",
         "Explore the radio spectrum around you with an RTL-SDR dongle. See signals, identify broadcasts, and listen in real time."),
        ("antenna.radiowaves.left.and.right", "Spectrum Analysis",
         "View a live spectrum waterfall, detect active signals, and identify what's transmitting — from FM radio to aircraft transponders."),
        ("speaker.wave.2.fill", "Listen Live",
         "Demodulate FM, AM, and SSB signals directly in the app. Tune to weather stations, amateur radio, marine VHF, and more."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            let page = pages[currentPage]
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: page.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text(page.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? Color.blue : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    hasCompletedOnboarding = true
                    isPresented = false
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 380)
        .interactiveDismissDisabled()
    }
}
