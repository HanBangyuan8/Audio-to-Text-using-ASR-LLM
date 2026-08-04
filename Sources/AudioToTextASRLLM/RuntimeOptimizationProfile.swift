import Foundation

enum RuntimeChipFamily: String {
    case appleSilicon
    case intel
}

enum RuntimeOSFamily: String {
    case macOS1015Or11
    case macOS12
    case macOS13Or14
    case macOS15OrNewer
}

struct RuntimeOptimizationProfile {
    let chipFamily: RuntimeChipFamily
    let osFamily: RuntimeOSFamily

    static var current: RuntimeOptimizationProfile {
        RuntimeOptimizationProfile(
            chipFamily: detectedChipFamily,
            osFamily: detectedOSFamily
        )
    }

    private static var detectedChipFamily: RuntimeChipFamily {
        #if arch(arm64)
        return .appleSilicon
        #else
        return .intel
        #endif
    }

    private static var detectedOSFamily: RuntimeOSFamily {
        if #available(macOS 15.0, *) {
            return .macOS15OrNewer
        }
        if #available(macOS 13.0, *) {
            return .macOS13Or14
        }
        if #available(macOS 12.0, *) {
            return .macOS12
        }
        return .macOS1015Or11
    }

    var visibleTaskBudget: Int {
        switch (chipFamily, osFamily) {
        case (.appleSilicon, .macOS15OrNewer): 160
        case (.appleSilicon, .macOS13Or14): 132
        case (.appleSilicon, .macOS12): 96
        case (.appleSilicon, .macOS1015Or11): 64
        case (.intel, .macOS15OrNewer): 120
        case (.intel, .macOS13Or14): 96
        case (.intel, .macOS12): 72
        case (.intel, .macOS1015Or11): 48
        }
    }

    var transcriptSegmentRenderBudget: Int {
        switch (chipFamily, osFamily) {
        case (.appleSilicon, .macOS15OrNewer): 1_200
        case (.appleSilicon, .macOS13Or14): 900
        case (.appleSilicon, .macOS12): 640
        case (.appleSilicon, .macOS1015Or11): 360
        case (.intel, .macOS15OrNewer): 800
        case (.intel, .macOS13Or14): 640
        case (.intel, .macOS12): 480
        case (.intel, .macOS1015Or11): 280
        }
    }
}
