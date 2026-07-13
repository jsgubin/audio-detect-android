//
//  ContentView.swift
//  AudioDetect
//
//  SwiftUI 主界面
//  让用户选择要监听的声音类型，控制开始/停止监听
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var classifier = AudioClassifier()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 状态栏
                statusBar
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 监听控制区域
                        controlSection
                        
                        // 类别选择
                        categorySection
                        
                        // 阈值调节
                        thresholdSection
                        
                        // 最近识别结果
                        lastResultSection
                        
                        // 识别历史
                        historySection
                    }
                    .padding()
                }
            }
            .navigationTitle("🔊 声音识别")
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
            
            // 指环连接状态提示
            HStack(spacing: 4) {
                Image(systemName: "ring.circle")
                    .foregroundColor(.blue)
                Text("通知已开启")
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
        VStack(spacing: 16) {
            // 大按钮
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
            
            // 提示文字
            Text(classifier.isListening
                 ? "iPhone 正在监听麦克风，检测到声音后会发送通知到指环"
                 : "点击开始，iPhone 将实时监听环境中的声音")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Category Selection
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("选择要监听的声音")
                    .font(.headline)
                Spacer()
                Text("已选 \(classifier.selectedCategories.count) 项")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 使用 LazyVGrid 展示网格
            let columns = [GridItem(.adaptive(minimum: 100))]
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(SoundCategory.alertCategories, id: \.self) { category in
                    CategoryToggleButton(
                        category: category,
                        isSelected: classifier.selectedCategories.contains(category.rawValue),
                        action: { classifier.toggleCategory(category.rawValue) }
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
        Group {
            if let result = classifier.lastResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最新检测")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        Text(result.icon)
                            .font(.system(size: 40))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.displayName)
                                .font(.title2.bold())
                            Text("置信度: \(Int(result.confidence * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(result.timestamp, style: .time)
                                .font(.caption)
                                .foregroundColor(.gray)
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
        }
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("识别历史")
                    .font(.headline)
                Spacer()
                if !classifier.detectionHistory.isEmpty {
                    Button("清空") {
                        classifier.clearHistory()
                    }
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
                    ForEach(classifier.detectionHistory) { result in
                        HistoryRow(result: result)
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

/// 类别切换按钮
struct CategoryToggleButton: View {
    let category: SoundCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(category.icon)
                    .font(.title2)
                Text(category.displayName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// 历史记录行
struct HistoryRow: View {
    let result: ClassificationResult
    
    var body: some View {
        HStack(spacing: 12) {
            Text(result.icon)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayName)
                    .font(.subheadline.bold())
                Text(result.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(Int(result.confidence * 100))%")
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
