import Foundation

// MARK: - Session

struct OpenCodeSession: Codable, Identifiable, Sendable {
    let id: String
    let projectID: String
    let directory: String
    let parentID: String?
    let title: String
    let version: String
    let time: SessionTime
    let share: SessionShare?
    let summary: SessionSummary?
    let revert: SessionRevert?

    struct SessionTime: Codable {
        let created: Double
        let updated: Double
    }

    struct SessionShare: Codable {
        let url: String
    }

    struct SessionSummary: Codable {
        let additions: Int
        let deletions: Int
        let files: Int
    }

    struct SessionRevert: Codable {
        let messageID: String
        let partID: String?
    }
}

// MARK: - Session Status

enum OpenCodeSessionStatus: Codable, Equatable, Sendable {
    case idle
    case busy
    case retry(attempt: Int, message: String, next: Double)

    enum CodingKeys: String, CodingKey {
        case type, attempt, message, next
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "idle":
            self = .idle
        case "busy":
            self = .busy
        case "retry":
            let attempt = try container.decode(Int.self, forKey: .attempt)
            let message = try container.decode(String.self, forKey: .message)
            let next = try container.decode(Double.self, forKey: .next)
            self = .retry(attempt: attempt, message: message, next: next)
        default:
            self = .idle
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .idle:
            try container.encode("idle", forKey: .type)
        case .busy:
            try container.encode("busy", forKey: .type)
        case .retry(let attempt, let message, let next):
            try container.encode("retry", forKey: .type)
            try container.encode(attempt, forKey: .attempt)
            try container.encode(message, forKey: .message)
            try container.encode(next, forKey: .next)
        }
    }
}

// MARK: - Messages

struct OpenCodeMessageEnvelope: Codable, Sendable {
    let info: OpenCodeMessage
    let parts: [OpenCodePart]
}

enum OpenCodeMessage: Codable, Sendable {
    case user(UserMessage)
    case assistant(AssistantMessage)

    struct UserMessage: Codable {
        let id: String
        let sessionID: String
        let role: String
        let time: MessageTime
        let agent: String
        let model: ModelRef
    }

    struct AssistantMessage: Codable {
        let id: String
        let sessionID: String
        let role: String
        let time: MessageTime
        let parentID: String
        let modelID: String
        let providerID: String
        let mode: String
        let cost: Double
        let tokens: TokenUsage
        let finish: String?
        let error: MessageError?
    }

    struct MessageTime: Codable {
        let created: Double
        let completed: Double?
    }

    struct TokenUsage: Codable {
        let input: Int
        let output: Int
        let reasoning: Int
    }

    struct MessageError: Codable {
        let name: String
        let data: MessageErrorData

        struct MessageErrorData: Codable {
            let message: String?
        }
    }

    var id: String {
        switch self {
        case .user(let m): return m.id
        case .assistant(let m): return m.id
        }
    }

    var role: String {
        switch self {
        case .user: return "user"
        case .assistant: return "assistant"
        }
    }

    var createdAt: Double {
        switch self {
        case .user(let m): return m.time.created
        case .assistant(let m): return m.time.created
        }
    }

    enum CodingKeys: String, CodingKey {
        case role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let role = try container.decode(String.self, forKey: .role)
        switch role {
        case "user":
            self = .user(try UserMessage(from: decoder))
        case "assistant":
            self = .assistant(try AssistantMessage(from: decoder))
        default:
            self = .user(try UserMessage(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .user(let m): try m.encode(to: encoder)
        case .assistant(let m): try m.encode(to: encoder)
        }
    }
}

// MARK: - Parts

enum OpenCodePart: Codable, Identifiable, Sendable {
    case text(TextPart)
    case tool(ToolPart)
    case stepStart(StepStartPart)
    case stepFinish(StepFinishPart)
    case reasoning(ReasoningPart)
    case file(FilePart)
    case other(OtherPart)

    // MARK: Text
    struct TextPart: Codable {
        let id: String
        let sessionID: String
        let messageID: String
        let text: String
        let synthetic: Bool?
    }

    // MARK: Tool
    struct ToolPart: Codable {
        let id: String
        let sessionID: String
        let messageID: String
        let callID: String
        let tool: String
        let state: ToolState

        enum ToolState: Codable {
            case pending(input: [String: AnyCodable])
            case running(input: [String: AnyCodable], title: String?)
            case completed(input: [String: AnyCodable], output: String, title: String)
            case error(input: [String: AnyCodable], error: String)

            var status: String {
                switch self {
                case .pending: return "pending"
                case .running: return "running"
                case .completed: return "completed"
                case .error: return "error"
                }
            }

            var title: String? {
                switch self {
                case .running(_, let t): return t
                case .completed(_, _, let t): return t
                default: return nil
                }
            }

            var output: String? {
                if case .completed(_, let o, _) = self { return o }
                return nil
            }

            var errorMessage: String? {
                if case .error(_, let e) = self { return e }
                return nil
            }

            enum CodingKeys: String, CodingKey {
                case status, input, title, output, error
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                let status = try c.decode(String.self, forKey: .status)
                let input = (try? c.decode([String: AnyCodable].self, forKey: .input)) ?? [:]
                switch status {
                case "pending":
                    self = .pending(input: input)
                case "running":
                    let title = try? c.decode(String.self, forKey: .title)
                    self = .running(input: input, title: title)
                case "completed":
                    let output = (try? c.decode(String.self, forKey: .output)) ?? ""
                    let title = (try? c.decode(String.self, forKey: .title)) ?? ""
                    self = .completed(input: input, output: output, title: title)
                default:
                    let error = (try? c.decode(String.self, forKey: .error)) ?? "Unknown error"
                    self = .error(input: input, error: error)
                }
            }

            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(status, forKey: .status)
            }
        }
    }

    // MARK: Step markers
    struct StepStartPart: Codable {
        let id: String
        let sessionID: String
        let messageID: String
    }

    struct StepFinishPart: Codable {
        let id: String
        let sessionID: String
        let messageID: String
        let reason: String
        let cost: Double
    }

    // MARK: Reasoning
    struct ReasoningPart: Codable {
        let id: String
        let sessionID: String
        let messageID: String
        let text: String
    }

    // MARK: File attachment
    struct FilePart: Codable {
        let id: String
        let sessionID: String
        let messageID: String
        let mime: String
        let filename: String?
        let url: String
    }

    // MARK: Catch-all for unknown part types
    struct OtherPart: Codable {
        let id: String
        let sessionID: String
        let messageID: String
        let type: String
    }

    // MARK: Identifiable
    var id: String {
        switch self {
        case .text(let p): return p.id
        case .tool(let p): return p.id
        case .stepStart(let p): return p.id
        case .stepFinish(let p): return p.id
        case .reasoning(let p): return p.id
        case .file(let p): return p.id
        case .other(let p): return p.id
        }
    }

    var messageID: String {
        switch self {
        case .text(let p): return p.messageID
        case .tool(let p): return p.messageID
        case .stepStart(let p): return p.messageID
        case .stepFinish(let p): return p.messageID
        case .reasoning(let p): return p.messageID
        case .file(let p): return p.messageID
        case .other(let p): return p.messageID
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "text":
            self = .text(try TextPart(from: decoder))
        case "tool":
            self = .tool(try ToolPart(from: decoder))
        case "step-start":
            self = .stepStart(try StepStartPart(from: decoder))
        case "step-finish":
            self = .stepFinish(try StepFinishPart(from: decoder))
        case "reasoning":
            self = .reasoning(try ReasoningPart(from: decoder))
        case "file":
            self = .file(try FilePart(from: decoder))
        default:
            self = .other(try OtherPart(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let p): try p.encode(to: encoder)
        case .tool(let p): try p.encode(to: encoder)
        case .stepStart(let p): try p.encode(to: encoder)
        case .stepFinish(let p): try p.encode(to: encoder)
        case .reasoning(let p): try p.encode(to: encoder)
        case .file(let p): try p.encode(to: encoder)
        case .other(let p): try p.encode(to: encoder)
        }
    }
}

// MARK: - Provider & Model

struct OpenCodeProviderList: Codable, Sendable {
    let all: [OpenCodeProvider]
    let connected: [String]
    let `default`: [String: String]
}

struct OpenCodeProvider: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let source: String
    let models: [String: OpenCodeModel]

    var sortedModels: [OpenCodeModel] {
        models.values.sorted { $0.name < $1.name }
    }
}

struct OpenCodeModel: Codable, Identifiable, Sendable {
    let id: String
    let providerID: String
    let name: String
    let status: String?
}

// MARK: - Agent

struct OpenCodeAgent: Codable, Identifiable, Sendable {
    let name: String
    let description: String?
    let mode: String
    let builtIn: Bool
    let color: String?

    var id: String { name }
}

// MARK: - Model reference (used when sending messages or changing config)

struct ModelRef: Codable, Sendable {
    let providerID: String
    let modelID: String
}

// MARK: - SSE Events

struct OpenCodeSSEEvent {
    let type: String
    let data: String
}

enum OpenCodeEvent {
    case sessionCreated(OpenCodeSession)
    case sessionUpdated(OpenCodeSession)
    case sessionDeleted(OpenCodeSession)
    case sessionStatus(sessionID: String, status: OpenCodeSessionStatus)
    case messagePartUpdated(part: OpenCodePart, delta: String?)
    case messageUpdated(info: OpenCodeMessage)
    case messageRemoved(sessionID: String, messageID: String)
    case permissionUpdated(OpenCodePermission)
    case serverConnected
    case unknown(type: String)
}

struct OpenCodePermission: Codable, Identifiable, Sendable {
    let id: String
    let type: String
    let sessionID: String
    let messageID: String
    let title: String
    let time: PermissionTime

    struct PermissionTime: Codable {
        let created: Double
    }
}

// MARK: - AnyCodable (for opaque JSON dicts)

struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool: try container.encode(bool)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        default: try container.encodeNil()
        }
    }
}

// MARK: - Message send request

struct SendMessageRequest: Codable, Sendable {
    let parts: [MessagePart]
    let model: ModelRef?
    let agent: String?

    struct MessagePart: Codable {
        let type: String
        let text: String
    }
}

// MARK: - Project info

struct OpenCodeProject: Codable, Identifiable, Sendable {
    let id: String
    let worktree: String
    let vcs: String?
}

// MARK: - Config (subset relevant to iOS)

struct OpenCodeConfig: Codable, Sendable {
    /// Current model in "providerID/modelID" format, e.g. "anthropic/claude-sonnet-4-5"
    let model: String?
    let theme: String?
}
