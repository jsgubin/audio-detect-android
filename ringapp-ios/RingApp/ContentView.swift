import SwiftUI

/// 设置引导界面
///
/// 本 App 不自己跑识别模型，而是利用 iOS 系统「声音识别」+ Shortcuts 自动化。
/// 此界面引导用户完成以下 3 步设置：
///   1. 在系统设置中开启「声音识别」
///   2. 创建 Shortcuts 自动化：声音识别触发 → 发送警报
///   3. 确保指环通过 ANCS 连接到 iPhone
struct ContentView: View {

    @State private var showTestAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // ── 标题 ──
                    headerSection

                    // ── 步骤 1：开启系统声音识别 ──
                    setupStep(
                        number: "1",
                        icon: "ear.badge.waveform",
                        title: "开启系统「声音识别」",
                        description: "前往 iPhone 设置 → 辅助功能 → 声音识别，打开开关。\n\n系统将使用设备端 AI 持续监听环境声音，无需联网。",
                        actionTitle: "打开设置",
                        actionURL: "App-prefs:ACCESSIBILITY"
                    )

                    // ── 步骤 2：配置 Shortcuts 自动化 ──
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Text("2")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("配置 Shortcuts 自动化")
                                    .font(.headline)
                                Image(systemName: "bolt.badge.automatic")
                                    .foregroundColor(.blue)
                            }
                        }

                        Text("打开 Shortcuts（快捷指令）App → 自动化 → 创建个人自动化 → 声音识别 → 选择要检测的声音类别 → 下一步 → 搜索「发送声音警报」→ 选择 → 完成。\n\n每种声音类别需要单独创建一条自动化规则。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)

                        Button(action: {
                            if let url = URL(string: "shortcuts://") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("打开 Shortcuts", systemImage: "app.connected.to.app.below.fill")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 8)

                    // ── 步骤 3：连接指环 ──
                    setupStepSimple(
                        number: "3",
                        icon: "ring.circle",
                        title: "确保指环已连接",
                        description: "指环需要支持 ANCS（Apple Notification Center Service）协议。\n\n确保指环已与 iPhone 蓝牙配对，并且指环的通知转发功能已开启。"
                    )

                    // ── 声音类别参考 ──
                    categoryReference

                    // ── 架构说明 ──
                    architectureInfo

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("🔊 声感指环")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.badge.waveform.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .padding(.bottom, 8)

            Text("环境声音 → 指环震动")
                .font(.title2.bold())

            Text("利用 iPhone 内建声音识别，将警报通过蓝牙发送给智能指环，即使手机静音也不会错过重要声音。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Step with action

    private func setupStep(
        number: String,
        icon: String,
        title: String,
        description: String,
        actionTitle: String,
        actionURL: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Text(number)
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                }
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)

            Button(action: {
                if let url = URL(string: actionURL) {
                    UIApplication.shared.open(url)
                }
            }) {
                Label(actionTitle, systemImage: "arrow.up.forward.app")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8)
    }

    private func setupStepSimple(
        number: String,
        icon: String,
        title: String,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Text(number)
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                }
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8)
    }

    // MARK: - Categories

    private var categoryReference: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("iOS 系统支持的声音类别")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(SoundCategory.allCases, id: \.rawValue) { category in
                    HStack(spacing: 4) {
                        Text(category.emoji)
                            .font(.caption)
                        Text(category.displayName)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8)
    }

    // MARK: - Architecture

    private var architectureInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("工作原理")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                flowRow("🎤", "iPhone 监听环境声音")
                flowArrow()
                flowRow("🧠", "iOS 系统声音识别（设备端 AI）")
                flowArrow()
                flowRow("⚡", "Shortcuts 自动化触发")
                flowArrow()
                flowRow("📱", "AppIntent 发送本地通知")
                flowArrow()
                flowRow("📡", "ANCS 蓝牙协议")
                flowArrow()
                flowRow("💍", "指环震动提醒")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8)
    }

    private func flowRow(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji)
            Text(text)
        }
    }

    private func flowArrow() -> some View {
        HStack {
            Text("↓")
                .padding(.leading, 12)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
