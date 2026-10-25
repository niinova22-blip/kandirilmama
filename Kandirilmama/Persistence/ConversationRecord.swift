import Foundation
import SwiftData

@Model
final class ConversationRecord {
    var createdAt: Date
    var duration: TimeInterval
    var scenarioID: String
    var transcript: String
    /// JSON olarak kodlanmış `AnalysisReport`.
    var reportData: Data?

    init(createdAt: Date, duration: TimeInterval, scenarioID: String, transcript: String, report: AnalysisReport) {
        self.createdAt = createdAt
        self.duration = duration
        self.scenarioID = scenarioID
        self.transcript = transcript
        self.reportData = try? JSONEncoder().encode(report)
    }

    var report: AnalysisReport? {
        guard let reportData else { return nil }
        return try? JSONDecoder().decode(AnalysisReport.self, from: reportData)
    }

    var scenario: Scenario? {
        ScenarioCatalog.scenario(id: scenarioID)
    }
}
