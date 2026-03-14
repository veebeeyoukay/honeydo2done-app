import SwiftUI

struct HouseholdView: View {
    @StateObject private var viewModel = HouseholdViewModel()

    var body: some View {
        NavigationView {
            List {
                // Current household
                if let household = viewModel.household {
                    Section("Household") {
                        HStack {
                            Image(systemName: "house.fill")
                                .foregroundColor(.blue)
                            Text(household.name)
                                .font(.headline)
                        }
                    }

                    // Members
                    Section("Members") {
                        ForEach(viewModel.members) { member in
                            HouseholdMemberRow(member: member)
                        }
                    }

                    // Properties
                    Section("Properties") {
                        ForEach(viewModel.properties) { property in
                            PropertyRow(property: property)
                        }

                        Button(action: {
                            // TODO: Add property
                        }) {
                            Label("Add Property", systemImage: "plus.circle")
                        }
                    }
                } else if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text("No household found")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Household")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // TODO: Invite member
                    }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
        }
        .task {
            await viewModel.loadHousehold()
        }
    }
}

struct HouseholdMemberRow: View {
    let member: HouseholdMemberDetail

    var body: some View {
        HStack {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(member.initials)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(member.fullName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(member.role)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let persona = member.personaOverride {
                        HStack(spacing: 4) {
                            Image(systemName: PersonaType(rawValue: persona)?.icon ?? "person")
                            Text(PersonaType(rawValue: persona)?.displayName ?? persona)
                        }
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
            }

            Spacer()
        }
    }
}

struct PropertyRow: View {
    let property: Property

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(property.name)
                .font(.headline)

            Text("\(property.city), \(property.state) \(property.zip)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

@MainActor
class HouseholdViewModel: ObservableObject {
    private let supabase = SupabaseClientManager.shared.client

    @Published var household: Household?
    @Published var members: [HouseholdMemberDetail] = []
    @Published var properties: [Property] = []
    @Published var isLoading = false

    func loadHousehold() async {
        isLoading = true

        do {
            guard let userId = try await supabase.auth.session.user.id.uuidString else {
                return
            }

            // Get user's household
            let memberResponse: [HouseholdMember] = try await supabase.database
                .from("household_members")
                .select("household_id")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value

            guard let householdId = memberResponse.first?.householdId else {
                isLoading = false
                return
            }

            // Get household details
            let householdResponse: Household = try await supabase.database
                .from("households")
                .select()
                .eq("id", value: householdId)
                .single()
                .execute()
                .value

            household = householdResponse

            // Get members
            let membersResponse: [HouseholdMemberDetail] = try await supabase.database
                .from("household_members")
                .select("*, users!inner(full_name)")
                .eq("household_id", value: householdId)
                .execute()
                .value

            members = membersResponse

            // Get properties
            let propertiesResponse: [Property] = try await supabase.database
                .from("properties")
                .select()
                .eq("household_id", value: householdId)
                .execute()
                .value

            properties = propertiesResponse

        } catch {
            print("Error loading household: \(error)")
        }

        isLoading = false
    }
}

struct Household: Codable {
    let id: String
    let name: String
    let createdBy: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdBy = "created_by"
    }
}

struct HouseholdMemberDetail: Codable, Identifiable {
    let id: String
    let householdId: String
    let userId: String
    let role: String
    let personaOverride: String?
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case id, role
        case householdId = "household_id"
        case userId = "user_id"
        case personaOverride = "persona_override"
        case fullName = "full_name"
    }

    var initials: String {
        let names = fullName.components(separatedBy: " ")
        let first = names.first?.prefix(1) ?? ""
        let last = names.count > 1 ? names.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
}

struct Property: Codable, Identifiable {
    let id: String
    let householdId: String
    let name: String
    let addressLine1: String
    let city: String
    let state: String
    let zip: String

    enum CodingKeys: String, CodingKey {
        case id, name, city, state, zip
        case householdId = "household_id"
        case addressLine1 = "address_line1"
    }
}
