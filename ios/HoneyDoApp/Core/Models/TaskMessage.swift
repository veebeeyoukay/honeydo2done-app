import Foundation

/// Task message (chat) model
struct TaskMessage: Identifiable, Codable {
    let id: String
    let taskId: String
    let senderId: String?
    let senderType: ActorType
    var content: String
    let personaUsed: PersonaType?
    var metadata: [String: AnyCodable]?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case senderId = "sender_id"
        case senderType = "sender_type"
        case content
        case personaUsed = "persona_used"
        case metadata
        case createdAt = "created_at"
    }

    var isFromUser: Bool {
        senderType == .user
    }

    var isFromAI: Bool {
        senderType == .ai
    }
}

enum ActorType: String, Codable {
    case user
    case ai
    case partner
    case system
}

enum PersonaType: String, Codable {
    case householdCEO = "household_ceo"
    case technicalPartner = "technical_partner"
    case patientGuide = "patient_guide"
    case diyMentor = "diy_mentor"

    var displayName: String {
        switch self {
        case .householdCEO: return "Household CEO"
        case .technicalPartner: return "Technical Partner"
        case .patientGuide: return "Patient Guide"
        case .diyMentor: return "DIY Mentor"
        }
    }

    var icon: String {
        switch self {
        case .householdCEO: return "house.fill"
        case .technicalPartner: return "wrench.and.screwdriver.fill"
        case .patientGuide: return "heart.fill"
        case .diyMentor: return "hammer.fill"
        }
    }
}
