import SwiftUI

struct AsyncAppIcon: View {
    let app: HomebrewApp
    let size: CGFloat

    @State private var loadedIcon: NSImage?
    @State private var isLoading = false

    private let iconLoader = IconLoaderService.shared

    var body: some View {
        Group {
            if let icon = loadedIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ZStack {
                    Image(systemName: app.isCask ? "app.dashed" : "terminal.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundColor(.secondary.opacity(0.3))

                    ProgressView()
                        .scaleEffect(0.5)
                }
            } else {
                Image(systemName: app.isCask ? "app.dashed" : "terminal.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(size * 0.15)
        .task(id: app.id) {
            // Reset state when app changes
            loadedIcon = nil
            await loadIcon()
        }
    }

    private func loadIcon() async {
        isLoading = true
        loadedIcon = await iconLoader.loadIcon(for: app)
        isLoading = false
    }
}

struct AsyncAppIcon_Previews: PreviewProvider {
    static var previews: some View {
        AsyncAppIcon(
            app: HomebrewApp(
                name: "Visual Studio Code",
                token: "visual-studio-code",
                description: "Code editor",
                homepage: "https://code.visualstudio.com",
                version: "1.0.0",
                isInstalled: false,
                isCask: true,
                icon: nil,
                installSize: nil,
                dependencies: nil,
                analytics: nil
            ),
            size: 48
        )
        .padding()
    }
}
