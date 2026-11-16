import SwiftUI

struct LaunchView: View {
    let launch: LaunchCoordinator
    @State private var showsWebSettings = false

    var body: some View {
        switch launch.route {
        case .loading:
            LoadingView()
        case .native:
            NativeRootView()
                .environment(\.scenePhase, launch.scenePhase)
        case .web(let url):
            WebView(url: url)
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Spacer()
                        SmallIconButton(icon: "slider.horizontal.3", label: "Settings") {
                            showsWebSettings = true
                        }
                    }
                    .padding(.horizontal, 12)
                    .background(Neon.background)
                }
                .sheet(isPresented: $showsWebSettings) { WebLegalSettingsView().gameSheet() }
        }
    }
}

private struct LoadingView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            if let icon = UIImage(named: "icon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 250, maxHeight: 250)
                    .scaleEffect(isPulsing ? 0.7 : 1)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
            } else {
                ProgressView()
            }
        }
    }
}
