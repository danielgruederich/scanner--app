import Foundation

extension String {
    /// Card ID is a numeric string, optionally with dashes, at least 5 chars
    var isValidCardID: Bool {
        let stripped = self.replacingOccurrences(of: "-", with: "")
        guard stripped.count >= 5 else { return false }
        return stripped.allSatisfy(\.isNumber)
    }
}
