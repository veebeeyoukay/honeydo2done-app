import Foundation

/// Task model matching Supabase schema
struct Task: Identifiable, Codable {
    let id: String
    let householdId: String
    let propertyId: String?
    let createdBy: String
    let assignedTo: String?
    let partnerId: String?

    var title: String
    var description: String
    var status: TaskStatus
    var priority: TaskPriority
    var category: TaskCategory?

    var structuredData: [String: AnyCodable]?
    var triageData: [String: AnyCodable]?

    var wantsPro: Bool
    var isDiy: Bool
    var isExtendedFamily: Bool

    var scheduledAt: Date?
    var startedAt: Date?
    var completedAt: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case propertyId = "property_id"
        case createdBy = "created_by"
        case assignedTo = "assigned_to"
        case partnerId = "partner_id"
        case title, description, status, priority, category
        case structuredData = "structured_data"
        case triageData = "triage_data"
        case wantsPro = "wants_pro"
        case isDiy = "is_diy"
        case isExtendedFamily = "is_extended_family"
        case scheduledAt = "scheduled_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum TaskStatus: String, Codable {
    case captured
    case triaging
    case awaitingDecision = "awaiting_decision"
    case diyInProgress = "diy_in_progress"
    case proRequested = "pro_requested"
    case proAssigned = "pro_assigned"
    case scheduled
    case inProgress = "in_progress"
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .captured: return "Captured"
        case .triaging: return "Triaging"
        case .awaitingDecision: return "Awaiting Decision"
        case .diyInProgress: return "DIY In Progress"
        case .proRequested: return "Pro Requested"
        case .proAssigned: return "Pro Assigned"
        case .scheduled: return "Scheduled"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
}

enum TaskPriority: String, Codable {
    case low
    case normal
    case high
    case urgent

    var displayName: String {
        rawValue.capitalized
    }
}

enum TaskCategory: String, Codable {
    case smartHome = "smart_home"
    case techGuard = "tech_guard"
    case aquaTech = "aqua_tech"
    case garageTech = "garage_tech"
    case hvac
    case electrical
    case plumbing
    case general
    case other

    var displayName: String {
        switch self {
        case .smartHome: return "Smart Home"
        case .techGuard: return "Tech Guard"
        case .aquaTech: return "Aqua Tech"
        case .garageTech: return "Garage Tech"
        case .hvac: return "HVAC"
        case .electrical: return "Electrical"
        case .plumbing: return "Plumbing"
        case .general: return "General"
        case .other: return "Other"
        }
    }
}

/// Helper type for dynamic JSON
struct AnyCodable: Codable {
    let value: Any

    init<T>(_ value: T?) {
        self.value = value ?? ()
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
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = ()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
