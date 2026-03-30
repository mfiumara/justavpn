import Foundation

public enum PauseDuration: Int, CaseIterable, Identifiable {
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case oneHour = 3600

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .oneHour: return "1 hour"
        }
    }
}
