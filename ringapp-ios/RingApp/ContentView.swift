import SwiftUI

/// 主界面：设置引导 + BLE 指环连接
///
/// 两个 Tab：
///   1. 设置引导：3 步完成系统声音识别 + Shortcuts 自动化配置
///   2. BLE 指环：扫描、连接指环、发送测试震动
struct ContentView: View {

    @EnvironmentObject var bleManager: RingBLEManager
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ── BLE 状态栏 ──
                bleStatusBar

                // ── Tab 切换 ──
                Picker("", selection: $selectedTab) {
                    Text("📋 设置引导").tag(0)
                    Text("💍 BLE 指环").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // ── Tab 内容 ──
                if selectedTab == 0 {
                    SetupGuideView()
                } else {
                    BLEDeviceView()
                }
            }
            .navigationTitle("🔊 声感指环")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - BLE Status Bar

    private var bleStatusBar: some View {
        HStack {
            Circle()
                .fill(bleStateColor)
                .frame(width: 10, height: 10)

            Text(bleManager.state.rawValue)
                .font(.subheadline)
                .foregroundColor(bleStateColor)

            Spacer()

            if bleManager.state == .scanning {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private var bleStateColor: Color {
        switch bleManager.state {
        case .connected:    return .green
        case .connecting, .scanning: return .orange
        default:            return .gray
        }
    }
}

// MARK: - Setup Guide Tab

struct SetupGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题
                VStack(spacing: 8) {
                    Image(systemName: "bell.badge.waveform.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                    Text("环境声音 → 指环震动")
                        .font(.title2.bold())
                    Text("利用 iPhone 内建声音识别，通过蓝牙发送震动指令给指环")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()

                // 步骤 1
                stepCard(
                    number: "1", icon: "ear.badge.waveform",
                    title: "开启系统「声音识别」",
                    desc: "前往 iPhone 设置 → 辅助功能 → 声音识别，打开开关。系统用设备端 AI 监听环境声音。",
                    buttonTitle: "打开设置",
                    url: "App-prefs:ACCESSIBILITY"
                )

                // 步骤 2
                stepCard(
                    number: "2", icon: "bolt.badge.automatic",
                    title: "配置 Shortcuts 自动化",
                    desc: "Shortcuts → 自动化 → 创建个人自动化 → 声音识别 → 选类别 → 搜索「发送声音警报」→ 完成。每种声音单独创建一条。",
                    buttonTitle: "打开 Shortcuts",
                    url: "shortcuts://"
                )

                // 步骤 3
                stepCardSimple(
                    number: "3", icon: "antenna.radiowaves.left.and.right",
                    title: "连接指环（BLE）",
                    desc: "切换到「💍 BLE 指环」Tab，扫描并连接你的指环。连接成功后，声音检测到的震动指令将通过蓝牙直接发送给指环。"
                )

                // 流程说明
                flowCard()
            }
            .padding()
        }
    }

    private func stepCard(number: String, icon: String, title: String, desc: String, buttonTitle: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                stepBadge(number)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Image(systemName: icon).foregroundColor(.blue)
                }
            }
            Text(desc).font(.subheadline).foregroundColor(.secondary).lineSpacing(4)
            if let u = URL(string: url) {
                Link(destination: u) {
                    Label(buttonTitle, systemImage: "arrow.up.forward.app")
                        .font(.subheadline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private func stepCardSimple(number: String, icon: String, title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                stepBadge(number)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Image(systemName: icon).foregroundColor(.blue)
                }
            }
            Text(desc).font(.subheadline).foregroundColor(.secondary).lineSpacing(4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private func stepBadge(_ num: String) -> some View {
        ZStack {
            Circle().fill(Color.blue.opacity(0.1)).frame(width: 36, height: 36)
            Text(num).font(.headline).foregroundColor(.blue)
        }
    }

    private func flowCard() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("完整链路").font(.headline).padding(.bottom, 4)
            flowRow("🎤", "iPhone 监听环境声音")
            flowArrow()
            flowRow("🧠", "iOS 系统声音识别")
            flowArrow()
            flowRow("⚡", "Shortcuts 自动化触发")
            flowArrow()
            flowRow("📲", "AppIntent → RingBLEManager")
            flowArrow()
            flowRow("📡", "CoreBluetooth GATT 写入")
            flowArrow()
            flowRow("💍", "指环震动")
        }
        .font(.caption).foregroundColor(.secondary)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    private func flowRow(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 8) { Text(emoji); Text(text) }
    }

    private func flowArrow() -> some View {
        Text("↓").padding(.leading, 12)
    }
}

// MARK: - BLE Device Tab

struct BLEDeviceView: View {

    @EnvironmentObject var bleManager: RingBLEManager
    @State private var testCategory: SoundCategory = .doorbell

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 扫描/断开按钮
                HStack(spacing: 12) {
                    Button(action: {
                        if bleManager.state == .scanning {
                            bleManager.stopScan()
                        } else {
                            bleManager.startScan()
                        }
                    }) {
                        Label(
                            bleManager.state == .scanning ? "停止扫描" : "开始扫描",
                            systemImage: bleManager.state == .scanning ? "stop.fill" : "magnifyingglass"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button(action: { bleManager.disconnect() }) {
                        Label("断开", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(bleManager.state != .connected)
                }

                // 设备列表
                if !bleManager.discoveredDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("发现的设备").font(.headline).padding(.bottom, 4)
                        ForEach(bleManager.discoveredDevices) { device in
                            Button(action: { bleManager.connect(device.peripheral) }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.name).font(.subheadline.bold())
                                        Text("\(device.rssi) dBm").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if bleManager.state == .connecting {
                                        ProgressView().scaleEffect(0.7)
                                    } else {
                                        Text("连接 →").font(.caption).foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else if bleManager.state == .scanning {
                    HStack {
                        ProgressView()
                        Text("正在扫描指环设备...").font(.subheadline).foregroundColor(.secondary)
                    }
                } else {
                    Text("未发现指环设备\n请确保指环已开机并靠近手机")
                        .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                        .padding()
                }

                // 测试震动
                if bleManager.state == .connected {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("测试震动").font(.headline)

                        Picker("声音类别", selection: $testCategory) {
                            ForEach(SoundCategory.allCases, id: \.rawValue) { cat in
                                Text("\(cat.emoji) \(cat.displayName)").tag(cat)
                            }
                        }
                        .pickerStyle(.menu)

                        Button(action: {
                            bleManager.sendVibration(category: testCategory)
                        }) {
                            Label("发送测试震动", systemImage: "dot.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }

                // 日志
                if !bleManager.logMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BLE 日志").font(.headline)
                        ScrollView {
                            Text(bleManager.logMessages.joined(separator: "\n"))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 150)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(RingBLEManager.shared)
    }
}
