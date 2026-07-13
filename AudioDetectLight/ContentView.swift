//
//  ContentView.swift
//  AudioDetectLight
//
//  SwiftUI 主界面：配置向导 + 快捷指令设置指南
//  本 App 不录音、不做 AI，只作为"通知中转站"
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showSetupGuide = true
    
    // 设置步骤状态
    @State private var step1Done = false
    @State private var step2Done = false
    @State private var step3Done = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部标题区
                    headerSection
                    
                    // 通知权限状态
                    notificationStatusSection
                    
                    // 设置向导（分步骤）
                    setupGuideSection
                    
                    // 快捷指令测试
                    testSection
                    
                    // FAQ
                    faqSection
                }
                .padding()
            }
            .navigationTitle("声音警报")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            checkNotificationStatus()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("声音识别 → 指环震动")
                .font(.title2.bold())
            
            Text("本 App 不录音、不做 AI，只作为系统声音识别和指环之间的"桥梁"")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Notification Status
    
    private var notificationStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("通知权限")
                    .font(.headline)
                Spacer()
                statusBadge
            }
            
            Text("指环通过通知来震动，必须开启通知权限。")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if notificationStatus != .authorized {
                Button("请求通知权限") {
                    NotificationManager.shared.requestAuthorization()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        checkNotificationStatus()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch notificationStatus {
            case .authorized: return ("已授权", .green)
            case .denied: return ("被拒绝", .red)
            case .notDetermined: return ("未申请", .orange)
            default: return ("未知", .gray)
            }
        }()
        
        return Text(text)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(8)
    }
    
    // MARK: - Setup Guide
    
    private var setupGuideSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置向导")
                .font(.headline)
            
            Text("按以下 3 步完成配置，之后即可使用。")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Step 1
            StepCard(
                number: 1,
                title: "开启 iPhone 系统声音识别",
                description: "设置 → 辅助功能 → 声音识别 → 开启\n选择要监听的声音（如婴儿啼哭、敲门声）",
                isDone: $step1Done
            )
            
            // Step 2
            StepCard(
                number: 2,
                title: "在指环 App 中允许通知",
                description: "打开指环配套 App → 消息提醒 → 开启"系统通知"",
                isDone: $step2Done
            )
            
            // Step 3
            StepCard(
                number: 3,
                title: "配置快捷指令自动化",
                description: "打开快捷指令 App → 自动化 → 创建个人自动化\n选择"声音识别" → 选择声音 → 添加动作"发送声音警报"",
                isDone: $step3Done
            )
            
            // 快捷指令配置示意图
            if !step3Done {
                Button("查看详细配置步骤") {
                    showShortcutGuide = true
                }
                .buttonStyle(.bordered)
                .sheet(isPresented: $showShortcutGuide) {
                    ShortcutGuideView()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    @State private var showShortcutGuide = false
    
    // MARK: - Test Section
    
    private var testSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("测试发送")
                .font(.headline)
            
            Text("手动发送一条通知，测试指环是否能震动。")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach([SoundType.doorKnock, SoundType.babyCry, SoundType.fireAlarm], id: \.self) { type in
                    Button {
                        NotificationManager.shared.sendSoundAlert(
                            soundType: type,
                            intensity: .medium,
                            repeatCount: 1
                        )
                    } label: {
                        VStack {
                            Text(type.icon)
                                .font(.title2)
                            Text(type.displayName)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - FAQ
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("常见问题")
                .font(.headline)
            
            FAQItem(
                question: "为什么 App 自己不做声音识别？",
                answer: "iPhone 系统的声音识别已经做得很好，我们直接利用它，省电且准确。本 App 只负责把识别结果转发给指环。"
            )
            
            FAQItem(
                question: "为什么必须走快捷指令？",
                answer: "iOS 不允许第三方 App 直接监听系统声音识别的结果。快捷指令是苹果官方提供的桥梁，安全且合法。"
            )
            
            FAQItem(
                question: "指环没有震动怎么办？",
                answer: "1. 确认指环已连接 iPhone\n2. 确认指环 App 允许接收系统通知\n3. 在上方"测试发送"中手动发送一条通知，看是否震动"
            )
            
            FAQItem(
                question: "这个 App 耗电吗？",
                answer: "几乎不耗电。App 本身不录音、不做 AI，只在快捷指令调用时短暂运行（约 0.1 秒），然后立即退出。"
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Helpers
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }
}

// MARK: - Subviews

/// 步骤卡片
struct StepCard: View {
    let number: Int
    let title: String
    let description: String
    @Binding var isDone: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 步骤编号
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : Color.blue)
                    .frame(width: 32, height: 32)
                
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            
            Spacer()
            
            // 完成按钮
            Button {
                isDone.toggle()
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isDone ? .green : .gray)
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
    }
}

/// FAQ 项
struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(question)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shortcut Guide Sheet

struct ShortcutGuideView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("快捷指令配置详细步骤")
                        .font(.title2.bold())
                    
                    GuideStep(number: 1, title: "打开快捷指令 App", content: "在 iPhone 上找到"快捷指令"App 并打开。")
                    
                    GuideStep(number: 2, title: "切换到"自动化"标签", content: "点击底部"自动化"标签，然后点击右上角"+"号。")
                    
                    GuideStep(number: 3, title: "选择触发器", content: "向下滚动，找到并点击"声音识别"。\n选择你想监听的声音，比如"婴儿啼哭"或"敲门声"。")
                    
                    GuideStep(number: 4, title: "添加动作", content: "在搜索框中输入"声音警报"或"AudioDetect"。\n找到"发送声音警报"，点击添加。")
                    
                    GuideStep(number: 5, title: "配置参数", content: "声音类别：选择对应的声音\n震动强度：选择"中"或"强"\n重复次数：一般设为 1")
                    
                    GuideStep(number: 6, title: "关闭"运行前询问"", content: "点击"运行前询问"开关，关闭它。\n这样声音识别触发后，会自动执行，不需要你确认。")
                    
                    GuideStep(number: 7, title: "保存", content: "点击右上角"完成"保存自动化。\n现在系统声音识别触发时，会自动通知指环震动。")
                    
                    Divider()
                    
                    Text("💡 提示")
                        .font(.headline)
                    
                    Text("你可以为每种声音创建不同的自动化，设置不同的震动强度。例如：\n• 婴儿啼哭 → 强震动，重复 3 次\n• 敲门声 → 中等震动，重复 1 次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("关闭") { dismiss() })
        }
    }
}

struct GuideStep: View {
    let number: Int
    let title: String
    let content: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
