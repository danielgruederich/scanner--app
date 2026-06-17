enum ScanMode {
    case stamp
    case redeem

    var label: String {
        switch self {
        case .stamp: return "Stempel"
        case .redeem: return "Einlösen"
        }
    }

    var icon: String {
        switch self {
        case .stamp: return "star.fill"
        case .redeem: return "gift.fill"
        }
    }
}
