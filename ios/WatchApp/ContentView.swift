import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject var connectivity: WatchConnectivityProvider
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            // Main screen - Time display and generic event button
            MainTimerView()
                .environmentObject(connectivity)
                .tag(0)

            // Secondary screen - Custom buttons list
            CustomButtonsView()
                .environmentObject(connectivity)
                .tag(1)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

struct MainTimerView: View {
    @EnvironmentObject var connectivity: WatchConnectivityProvider

    var body: some View {
        VStack(spacing: 12) {
            // Connection status indicator
            if !connectivity.isConnected {
                HStack {
                    Image(systemName: "iphone.slash")
                        .font(.caption)
                    Text("Disconnected")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
                .padding(.top, 4)
            }

            Spacer()

            // Time Display
            VStack(spacing: 4) {
                Text(connectivity.isAbsoluteTime ? "Time of Day" : "Running Time")
                    .font(.caption2)
                    .foregroundColor(.gray)

                Text(connectivity.currentTime)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            Spacer()

            // Generic Event Button
            Button(action: {
                captureGenericEvent()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Add Event")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(.horizontal, 8)
    }

    private func captureGenericEvent() {
        // Provide haptic feedback
        WKInterfaceDevice.current().play(.click)

        connectivity.captureEvent(buttonName: "Generic Event", color: "Default") { success in
            if success {
                // Success feedback
                WKInterfaceDevice.current().play(.success)
            } else {
                // Error feedback
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}

struct CustomButtonsView: View {
    @EnvironmentObject var connectivity: WatchConnectivityProvider

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Custom Events")
                    .font(.headline)
                    .padding(.top, 8)

                if connectivity.buttons.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No custom buttons")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Text("Add buttons in the iPhone app")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ForEach(connectivity.buttons) { button in
                        CustomEventButton(button: button)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}

struct CustomEventButton: View {
    @EnvironmentObject var connectivity: WatchConnectivityProvider
    let button: ButtonModel

    var body: some View {
        Button(action: {
            captureCustomEvent()
        }) {
            HStack {
                Circle()
                    .fill(button.swiftUIColor)
                    .frame(width: 8, height: 8)

                Text(button.name)
                    .font(.system(size: 14))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(button.swiftUIColor.opacity(0.2))
    }

    private func captureCustomEvent() {
        // Provide haptic feedback
        WKInterfaceDevice.current().play(.click)

        connectivity.captureEvent(buttonName: button.name, color: button.color) { success in
            if success {
                // Success feedback with notification haptic
                WKInterfaceDevice.current().play(.notification)
            } else {
                // Error feedback
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityProvider())
}
