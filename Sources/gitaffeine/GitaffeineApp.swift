import SwiftUI

@main
struct GitaffeineApp: App {
    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                Text("gitaffeine").font(.headline)
                Divider()
                Button("Quit gitaffeine") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding()
            .frame(width: 280, alignment: .leading)
        } label: {
            Image(nsImage: PillIcon.image)
        }
        .menuBarExtraStyle(.window)
    }
}
