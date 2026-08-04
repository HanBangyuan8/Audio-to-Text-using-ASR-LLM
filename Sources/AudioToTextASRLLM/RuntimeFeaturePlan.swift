import Foundation

struct RuntimeFeaturePlan {
    let profile: RuntimeOptimizationProfile

    static var current: RuntimeFeaturePlan {
        RuntimeFeaturePlan(profile: .current)
    }

    var usesSwiftUIAppLifecycle: Bool {
        profile.osFamily == .macOS13Or14 || profile.osFamily == .macOS15OrNewer
    }

    var persistenceDebounceNanoseconds: UInt64 {
        switch profile.osFamily {
        case .macOS15OrNewer: 120_000_000
        case .macOS13Or14: 180_000_000
        case .macOS12: 260_000_000
        case .macOS1015Or11: 420_000_000
        }
    }

    var configurationDebounceNanoseconds: UInt64 {
        switch profile.osFamily {
        case .macOS15OrNewer: 180_000_000
        case .macOS13Or14: 220_000_000
        case .macOS12: 280_000_000
        case .macOS1015Or11: 380_000_000
        }
    }

    var visibleTaskBudget: Int {
        profile.visibleTaskBudget
    }

    var transcriptSegmentRenderBudget: Int {
        profile.transcriptSegmentRenderBudget
    }
}
