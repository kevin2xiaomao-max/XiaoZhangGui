import Foundation

struct AICapabilityDocumentInput: Sendable, Equatable {
    let data: Data
    let fileName: String
    let mimeType: String
    let prompt: String
}

protocol AICapabilityDocumentProvider: Sendable {
    var id: String { get }
    func understand(_ input: AICapabilityDocumentInput, timeout: TimeInterval) async throws -> String
}

struct UnconfiguredDocumentProvider: AICapabilityDocumentProvider {
    let id = "unconfigured-document"

    func understand(_ input: AICapabilityDocumentInput, timeout: TimeInterval) async throws -> String {
        throw AICapabilityError.notConfigured(.documentUnderstanding)
    }
}

struct DocumentCapability: Sendable {
    private let provider: any AICapabilityDocumentProvider
    private let timeout: TimeInterval

    init(provider: any AICapabilityDocumentProvider = UnconfiguredDocumentProvider(), timeout: TimeInterval = 30) {
        self.provider = provider
        self.timeout = timeout
    }

    func execute(
        data: Data,
        fileName: String,
        mimeType: String,
        prompt: String = "请总结这个文件"
    ) async throws -> AICapabilityResult {
        guard !data.isEmpty, !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AICapabilityError.invalidDocument
        }
        do {
            let text = try await provider.understand(
                AICapabilityDocumentInput(data: data, fileName: fileName, mimeType: mimeType, prompt: prompt),
                timeout: timeout
            )
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AICapabilityError.malformedResponse
            }
            return AICapabilityResult(
                capability: .documentUnderstanding,
                text: text,
                provider: provider.id
            )
        } catch is CancellationError {
            throw AICapabilityError.cancelled
        } catch let error as AICapabilityError {
            throw error
        } catch {
            throw AICapabilityError.unavailable
        }
    }
}
