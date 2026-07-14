import SwiftUI

/// 主界面
struct ContentView: View {

    @StateObject private var classifier = SoundClassifier()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 状态栏
                statusBar

                ScrollView {
                    VStack(spacing: 20) {
                        // 控制按钮
                        controlSection

                        // 类别选择
                        categorySection

                        // 阈值调节
                        thresholdSection

                        // 最新检测
                        if classifier.lastDetection != nil {
                            lastResultSection
                        }

                        // 识别历史
                        historySection
                    }
                    .padding()
                }
            }
            .navigationTitle("🔊 声感指环")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Circle()
                .fill(classifier.isListening ? Color.green : Color.orange)
                .frame(width: 10, height: 10)

            Text(classifier.isListening ? "正在监听" : "已暂停")
                .font(.subheadline)
                .foregroundColor(classifier.isListening ? .green : .orange)

            Spacer()

            // 通知状态
            HStack(spacing: 4) {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("通知已就绪")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Control Section

    private var controlSection: some View {
        Button(action: toggleListening) {
            HStack(spacing: 12) {
                Image(systemName: classifier.isListening ? "stop.fill" : "mic.fill")
                    .font(.title2)
                Text(classifier.isListening ? "停止监听" : "开始监听")
                    .font(.title3.bold())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(classifier.isListening ? Color.red : Color.green)
            .cornerRadius(16)
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("选择要监听的声音")
                    .font(.headline)
                Spacer()
                Text("已选 \(classifier.selectedCategories.count) / \(SoundCategory.allCases.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let columns = [GridItem(.adaptive(minimum: 90))]

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(SoundCategory.allCases) { category in
                    CategoryToggleButton(
                        category: category,
                        isSelected: classifier.selectedCategories.contains(category),
                        action: { classifier.toggleCategory(category) }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Threshold Section

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("置信度阈值")
                    .font(.headline)
                Spacer()
                Text("\(Int(classifier.confidenceThreshold * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }

            Slider(
                value: $classifier.confidenceThreshold,
                in: 0.3...0.95,
                step: 0.05
            )

            HStack {
                Text("低 (容易误报)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("高 (减少误报)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Last Result

    private var lastResultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最新检测")
                .font(.headline)

            HStack(spacing: 16) {
                Text(classifier.lastDetection!.category.emoji)
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: 4) {
                    Text(classifier.lastDetection!.category.displayName)
                        .font(.title2.bold())
                    Text("置信度: \(Int(classifier.lastDetection!.confidence * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("识别历史")
                    .font(.headline)
                Spacer()
                if !classifier.detectionHistory.isEmpty {
                    Button("清空") { classifier.clearHistory() }
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }

            if classifier.detectionHistory.isEmpty {
                Text("暂无记录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(classifier.detectionHistory.prefix(30)) { record in
                        HistoryRow(record: record)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Actions

    private func toggleListening() {
        if classifier.isListening {
            classifier.stopListening()
        } else {
            classifier.startListening()
        }
    }
}

// MARK: - Subviews

struct CategoryToggleButton: View {
    let category: SoundCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(category.emoji)
                    .font(.title3)
                Text(category.displayName)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 55)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HistoryRow: View {
    let record: SoundClassifier.DetectionRecord

    var body: some View {
        HStack(spacing: 12) {
            Text(record.category.emoji)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.category.displayName)
                    .font(.subheadline.bold())
                Text(record.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(Int(record.confidence * 100))%")
                .font(.caption.bold())
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
