import SwiftUI

@main
struct RingApp: App {

    @StateObject private var classifier = SoundClassifier()

    init() {
        // 请求通知权限
        NotificationManager.shared.requestAuthorization()

        // 设置检测回调 → 发送通知 → 指环通过 ANCS 接收
        classifier.onDetection = { category, confidence in
            NotificationManager.shared.sendDetectionNotification(
                category: category,
                confidence: confidence
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(classifier)
        }
    }
}
