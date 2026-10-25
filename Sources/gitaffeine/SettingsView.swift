import SwiftUI

struct SettingsView: View {
    let email: String?

    var body: some View {
        TabView {
            Form {
                LabeledContent("작성자 이메일", value: email ?? "미설정")
                Text("전역 git user.email에서 읽습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .tabItem { Label("Git", systemImage: "point.3.connected.trianglepath.dotted") }
        }
        .frame(width: 360)
    }
}
