//
//  AudioClassifier.swift
//  AudioDetect
//
//  iOS 声音识别核心模块
//  使用 Apple SoundAnalysis 框架实时分析麦克风音频
//

import Foundation
import SoundAnalysis
import AVFoundation
import Combine

/// 声音分类结果
struct ClassificationResult: Identifiable {
    let id = UUID()
    let identifier: String      // 声音类别标识
    let confidence: Double      // 置信度 0.0~1.0
    let timestamp: Date
    
    /// 中文显示名称
    var displayName: String {
        SoundCategory(rawValue: identifier)?.displayName ?? identifier
    }
    
    /// 图标
    var icon: String {
        SoundCategory(rawValue: identifier)?.icon ?? "🔊"
    }
}

/// 支持的声音类别（与 Apple 内置模型对应）
enum SoundCategory: String, CaseIterable {
    case baby_cry = "baby_crying"
    case door_knock = "knocking"
    case doorbell = "doorbell"
    case fire_alarm = "fire_alarm"
    case smoke_alarm = "smoke_detector"
    case glass_break = "glass_breaking"
    case siren = "siren"
    case cat = "cat"
    case dog = "dog"
    case water_running = "water_running"
    case coughing = "coughing"
    case shouting = "shouting"
    
    /// 用户可选的类别（排除日常高频的咳嗽、猫狗等）
    static var alertCategories: [SoundCategory] {
        [.baby_cry, .door_knock, .doorbell, .fire_alarm, .smoke_alarm,
         .glass_break, .siren, .shouting]
    }
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .baby_cry: return "婴儿啼哭"
        case .door_knock: return "敲门声"
        case .doorbell: return "门铃声"
        case .fire_alarm: return "火灾警报"
        case .smoke_alarm: return "烟雾警报"
        case .glass_break: return "玻璃破碎"
        case .siren: return "警笛声"
        case .cat: return "猫叫声"
        case .dog: return "狗叫声"
        case .water_running: return "流水声"
        case .coughing: return "咳嗽声"
        case .shouting: return "喊叫声"
        }
    }
    
    /// 图标
    var icon: String {
        switch self {
        case .baby_cry: return "👶"
        case .door_knock: return "🚪"
        case .doorbell: return "🔔"
        case .fire_alarm: return "🔥"
        case .smoke_alarm: return "💨"
        case .glass_break: return "💥"
        case .siren: return "🚨"
        case .cat: return "🐱"
        case .dog: return "🐶"
        case .water_running: return "💧"
        case .coughing: return "😷"
        case .shouting: return "📢"
        }
    }
}

/// 音频分类器：管理麦克风输入和声音识别
class AudioClassifier: NSObject, ObservableObject, SNResultsObserving {
    
    // MARK: - Published Properties
    
    /// 是否正在监听
    @Published var isListening = false
    
    /// 最后一次识别结果
    @Published var lastResult: ClassificationResult?
    
    /// 识别历史
    @Published var detectionHistory: [ClassificationResult] = []
    
    /// 当前选择的监听类别
    @Published var selectedCategories: Set<String> = ["baby_crying", "knocking", "doorbell", "fire_alarm"]
    
    /// 置信度阈值 (0.0~1.0)
    @Published var confidenceThreshold: Double = 0.7
    
    // MARK: - Private Properties
    
    /// 音频引擎
    private var audioEngine = AVAudioEngine()
    
    /// 音频分析器
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    
    /// 声音识别请求
    private var classificationRequest: SNClassifySoundRequest?
    
    /// 防重复触发：记录上次触发时间
    private var lastTriggerTime: [String: Date] = [:]
    
    /// 最小触发间隔（秒）
    private let minTriggerInterval: TimeInterval = 3.0
    
    /// 通知管理器
    private let notificationManager = NotificationManager()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupAudioSession()
        notificationManager.requestAuthorization()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("音频会话配置失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Start/Stop Listening
    
    /// 开始监听麦克风
    func startListening() {
        guard !isListening else { return }
        
        // 获取输入格式
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // 创建分析器
        streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
        
        // 创建声音分类请求（使用 Apple 内置模型）
        do {
            classificationRequest = try SNClassifySoundRequest(classifierIdentifier: .version1)
            guard let request = classificationRequest else { return }
            
            try streamAnalyzer?.add(request, withObserver: self)
        } catch {
            print("创建识别请求失败: \(error.localizedDescription)")
            return
        }
        
        // 安装 Tap 捕获音频
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, _ in
            self?.streamAnalyzer?.analyze(buffer, atAudioFramePosition: buffer.frameLength)
        }
        
        // 启动音频引擎
        do {
            try audioEngine.start()
            isListening = true
            print("🎙️ 开始监听...")
        } catch {
            print("启动音频引擎失败: \(error.localizedDescription)")
        }
    }
    
    /// 停止监听
    func stopListening() {
        guard isListening else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        if let request = classificationRequest {
            streamAnalyzer?.remove(request)
        }
        
        streamAnalyzer = nil
        classificationRequest = nil
        isListening = false
        
        print("⏹ 停止监听")
    }
    
    // MARK: - SNResultsObserving
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        
        // 取置信度最高的结果
        guard let topClassification = result.classifications.first else { return }
        
        let identifier = topClassification.identifier
        let confidence = topClassification.confidence
        
        // 检查是否在用户选择的类别中
        guard selectedCategories.contains(identifier) else { return }
        
        // 检查置信度阈值
        guard confidence >= confidenceThreshold else { return }
        
        // 防重复触发检查
        if let lastTime = lastTriggerTime[identifier] {
            if Date().timeIntervalSince(lastTime) < minTriggerInterval {
                return  // 太短，忽略
            }
        }
        
        // 记录触发时间
        lastTriggerTime[identifier] = Date()
        
        // 创建结果
        let classificationResult = ClassificationResult(
            identifier: identifier,
            confidence: confidence,
            timestamp: Date()
        )
        
        // 更新 UI
        DispatchQueue.main.async { [weak self] in
            self?.lastResult = classificationResult
            self?.detectionHistory.insert(classificationResult, at: 0)
            
            // 限制历史记录数量
            if self?.detectionHistory.count ?? 0 > 50 {
                self?.detectionHistory.removeLast()
            }
        }
        
        // 发送通知到指环
        notificationManager.sendDetectionNotification(result: classificationResult)
    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("识别请求失败: \(error.localizedDescription)")
    }
    
    func requestDidComplete(_ request: SNRequest) {
        print("识别请求完成")
    }
    
    // MARK: - Category Management
    
    /// 切换类别选择状态
    func toggleCategory(_ identifier: String) {
        if selectedCategories.contains(identifier) {
            selectedCategories.remove(identifier)
        } else {
            selectedCategories.insert(identifier)
        }
    }
    
    /// 清除历史记录
    func clearHistory() {
        detectionHistory.removeAll()
    }
}
