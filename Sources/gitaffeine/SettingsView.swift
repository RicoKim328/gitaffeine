import SwiftUI

struct SettingsView: View {
    let account: String?
    let fromGitHub: Bool

    var body: some View {
        TabView {
            Form {
                LabeledContent("계정", value: account ?? "미설정")
                Text(fromGitHub ? "gh CLI에 로그인한 GitHub 계정입니다." : "gh 로그인 전이라 전역 git user.email을 씁니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .tabItem { Label("Git", systemImage: "point.3.connected.trianglepath.dotted") }
        }
        .frame(width: 360)
    }
}
