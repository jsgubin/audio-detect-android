import Foundation
import SoundAnalysis
import AVFoundation

/// 声音分类器 — 使用 Apple SoundAnalysis 框架
///
/// Apple 的 SNClassifySoundRequest 内建了约 300 种声音的分类模型，
/// 在设备端本地运行，无需联网，不消耗流量。
///
/// 用法：
/// ```
///   let classifier = SoundClassifier()
///   classifier.onDetection = { category, confidence in ... }
///   classifier.startListening()
/// ```
@MainActor
class SoundClassifier: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isListening = false
    @Published var lastDetection: (category: SoundCategory, confidence: Float)?
    @Published var detectionHistory: [DetectionRecord] = []
    @Published var selectedCategories: Set<SoundCategory> = SoundCategory.defaultSelected
    @Published var confidenceThreshold: Float = 0.55

    struct DetectionRecord: Identifiable {
        let id = UUID()
        let category: SoundCategory
        let confidence: Float
        let timestamp: Date
    }

    // MARK: - Callbacks

    var onDetection: ((SoundCategory, Float) -> Void)?

    // MARK: - Private

    private let audioEngine = AVAudioEngine()
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    private var classifyRequest: SNClassifySoundRequest?
    private var resultsObserver: SoundResultsObserver?

    // 防抖：同一类别短时间内不重复通知
    private var lastNotificationTime: [SoundCategory: Date] = [:]
    private let debounceInterval: TimeInterval = 5.0

    // MARK: - Public API

    func startListening() {
        guard !isListening else { return }

        do {
            try setupAudioSession()
            try setupAnalyzer()
            isListening = true
        } catch {
            print("❌ 启动监听失败: \(error.localizedDescription)")
        }
    }

    func stopListening() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        streamAnalyzer = nil
        classifyRequest = nil
        resultsObserver = nil
        isListening = false
    }

    func toggleCategory(_ category: SoundCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func clearHistory() {
        detectionHistory.removeAll()
    }

    // MARK: - Setup

    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [])
        try session.setActive(true)
    }

    private func setupAnalyzer() throws {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)

        // iOS 内建声音分类请求
        classifyRequest = try SNClassifySoundRequest(classifierIdentifier: .version1)

        let observer = SoundResultsObserver { [weak self] result in
            self?.handleResult(result)
        }

        resultsObserver = observer

        // 安装音频 tap
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: inputFormat
        ) { [weak self] buffer, _ in
            self?.streamAnalyzer?.analyze(buffer, atAudioFramePosition: buffer.frameLength)
        }

        // 添加分析请求
        if let request = classifyRequest {
            try streamAnalyzer?.add(request, withObserver: observer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Result Handling

    private func handleResult(_ result: SNClassificationResult) {
        // 取置信度最高的分类
        guard let topClassification = result.classifications.first else { return }

        let confidence = Float(topClassification.confidence)
        let identifier = topClassification.identifier

        // 过滤低置信度
        guard confidence >= confidenceThreshold else { return }

        // 映射到我们的类别
        guard let category = mapSound(identifier: identifier) else { return }

        // 用户是否选中了此类别
        guard selectedCategories.contains(category) else { return }

        // 防抖
        if let lastTime = lastNotificationTime[category],
           Date().timeIntervalSince(lastTime) < debounceInterval {
            return
        }
        lastNotificationTime[category] = Date()

        // 记录
        let record = DetectionRecord(category: category, confidence: confidence, timestamp: Date())
        detectionHistory.insert(record, at: 0)
        if detectionHistory.count > 100 { detectionHistory.removeLast() }
        lastDetection = (category, confidence)

        // 回调
        print("🔊 \(category.emoji) \(category.displayName) (\(Int(confidence * 100))%)")
        onDetection?(category, confidence)
    }

    /// 将 Apple 的标识符映射到我们的 SoundCategory
    private func mapSound(identifier: String) -> SoundCategory? {
        SoundCategory.allCases.first { $0.appleLabel == identifier }
    }
}

// MARK: - Results Observer

/// SNResultsObserving 实现
private class SoundResultsObserver: NSObject, SNResultsObserving {
    private let handler: (SNClassificationResult) -> Void

    init(handler: @escaping (SNClassificationResult) -> Void) {
        self.handler = handler
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult else { return }
        DispatchQueue.main.async {
            self.handler(classificationResult)
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("SoundAnalysis error: \(error.localizedDescription)")
    }

    func requestDidComplete(_ request: SNRequest) {
        print("SoundAnalysis request completed")
    }
}
