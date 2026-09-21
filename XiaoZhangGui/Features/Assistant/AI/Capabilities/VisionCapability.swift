import Foundation

struct AICapabilityImageInput: Sendable, Equatable {
    let data: Data
    let mimeType: String
    let prompt: String
}

protocol AICapabilityVisionProvider: Sendable {
    var id: String { get }
    func analyze(_ input: AICapabilityImageInput, timeout: TimeInterval) async throws -> String
}

struct UnconfiguredVisionProvider: AICapabilityVisionProvider {
    let id = "unconfigured-vision"

    func analyze(_ input: AICapabilityImageInput, timeout: TimeInterval) async throws -> String {
        throw AICapabilityError.notConfigured(.vision)
    }
}

struct VisionCapability: Sendable {
    private let provider: any AICapabilityVisionProvider
    private let timeout: TimeInterval

    init(provider: any AICapabilityVisionProvider = UnconfiguredVisionProvider(), timeout: TimeInterval = 30) {
        self.provider = provider
        self.timeout = timeout
    }

    func execute(imageData: Data, mimeType: String, prompt: String = "请描述这张图片") async throws -> AICapabilityResult {
        guard !imageData.isEmpty, mimeType.lowercased().hasPrefix("image/") else {
            throw AICapabilityError.invalidImage
        }
        do {
            let text = try await provider.analyze(
                AICapabilityImageInput(data: imageData, mimeType: mimeType, prompt: prompt),
                timeout: timeout
            )
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AICapabilityError.malformedResponse
            }
            return AICapabilityResult(capability: .vision, text: text, provider: provider.id)
        } catch is CancellationError {
            throw AICapabilityError.cancelled
        } catch let error as AICapabilityError {
            throw error
        } catch {
            throw AICapabilityError.unavailable
        }
    }
}
