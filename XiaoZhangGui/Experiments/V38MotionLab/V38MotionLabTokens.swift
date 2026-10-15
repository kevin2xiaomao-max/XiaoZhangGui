import SwiftUI

/// V3.8 Motion Lab values are independent trial tokens.
/// Production integration must map them to the verified V371 / V38 token source.
enum V38MotionLabTokens {
    enum Intent { case press, expand, contentChange }

    static func animation(for intent: Intent, reduceMotion: Bool) -> Animation? {
        if reduceMotion { return nil }
        switch intent {
        case .press: return .easeOut(duration: 0.18)
        case .expand: return .spring(response: 0.35, dampingFraction: 0.86)
        case .contentChange: return .easeInOut(duration: 0.28)
        }
    }

    static func allowsDecorativeMorph(reduceMotion: Bool) -> Bool { !reduceMotion }
}
