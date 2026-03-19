import SwiftUI

enum Theme {
    // FUERTE.DIGITAL brand colors
    static let gold = Color(red: 139/255, green: 115/255, blue: 0/255)       // #8B7300
    static let black = Color.black
    static let white = Color.white
    static let darkGray = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let errorRed = Color(red: 255/255, green: 59/255, blue: 48/255)
    static let successGreen = Color(red: 52/255, green: 199/255, blue: 89/255)

    // Typography
    static let titleFont = Font.system(size: 24, weight: .bold)
    static let bodyFont = Font.system(size: 16, weight: .regular)
    static let captionFont = Font.system(size: 12, weight: .regular)
    static let stampCountFont = Font.system(size: 48, weight: .bold, design: .rounded)

    // Spacing
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
}
