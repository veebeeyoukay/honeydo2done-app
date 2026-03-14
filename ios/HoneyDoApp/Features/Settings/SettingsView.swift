import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section("Profile") {
                    if let user = authService.currentUser {
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(user.initials)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.fullName)
                                    .font(.headline)

                                if let phone = user.phone {
                                    Text(phone)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }

                        NavigationLink(destination: PersonaSettingsView()) {
                            HStack {
                                Image(systemName: PersonaType(rawValue: user.personaType ?? "household_ceo")?.icon ?? "person")
                                Text("Persona")
                                Spacer()
                                Text(PersonaType(rawValue: user.personaType ?? "household_ceo")?.displayName ?? "Household CEO")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Preferences
                Section("Preferences") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("Notifications", systemImage: "bell.fill")
                    }

                    NavigationLink(destination: Text("Communication Preferences")) {
                        Label("Communication", systemImage: "message.fill")
                    }
                }

                // About
                Section("About") {
                    Link(destination: URL(string: "https://honeydone.com/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }

                    Link(destination: URL(string: "https://honeydone.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("0.1.0")
                            .foregroundColor(.secondary)
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive, action: {
                        showingLogoutAlert = true
                    }) {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await authService.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

struct PersonaSettingsView: View {
    @State private var selectedPersona: PersonaType = .householdCEO

    var body: some View {
        List {
            Section {
                Text("Choose how HoneyDo2Done communicates with you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section {
                ForEach([PersonaType.householdCEO, .technicalPartner, .patientGuide, .diyMentor], id: \.self) { persona in
                    Button(action: {
                        selectedPersona = persona
                    }) {
                        HStack {
                            Image(systemName: persona.icon)
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(persona.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(personaDescription(persona))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedPersona == persona {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Save") {
                    // TODO: Save persona preference
                }
                .frame(maxWidth: .infinity)
                .font(.headline)
            }
        }
        .navigationTitle("Persona")
    }

    private func personaDescription(_ persona: PersonaType) -> String {
        switch persona {
        case .householdCEO:
            return "Warm, efficient summaries for decision-makers"
        case .technicalPartner:
            return "Detailed technical briefs for the fix-it person"
        case .patientGuide:
            return "Simple, reassuring language"
        case .diyMentor:
            return "Step-by-step instructions with safety checks"
        }
    }
}

struct NotificationSettingsView: View {
    @State private var taskUpdates = true
    @State private var chatMessages = true
    @State private var proMatches = true
    @State private var reminders = true

    var body: some View {
        List {
            Section {
                Text("Choose which notifications you want to receive")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("Task Updates") {
                Toggle("Status changes", isOn: $taskUpdates)
                Toggle("Chat messages", isOn: $chatMessages)
                Toggle("Pro matches", isOn: $proMatches)
            }

            Section("Reminders") {
                Toggle("Scheduled tasks", isOn: $reminders)
            }
        }
        .navigationTitle("Notifications")
    }
}

extension User {
    var initials: String {
        let names = fullName.components(separatedBy: " ")
        let first = names.first?.prefix(1) ?? ""
        let last = names.count > 1 ? names.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
}
