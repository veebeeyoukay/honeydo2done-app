import Foundation
import Supabase
import Combine

/// Authentication service
@MainActor
class AuthService: ObservableObject {
    private let supabase = SupabaseClientManager.shared.client

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var error: Error?

    init() {
        Task {
            await checkAuthStatus()
        }
    }

    /// Check if user is authenticated
    func checkAuthStatus() async {
        do {
            let session = try await supabase.auth.session
            isAuthenticated = session.user != nil

            if isAuthenticated {
                await fetchCurrentUser()
            }
        } catch {
            isAuthenticated = false
            print("Auth check error: \(error)")
        }
    }

    /// Sign in with phone number
    func signInWithPhone(phoneNumber: String) async -> Bool {
        do {
            try await supabase.auth.signInWithOTP(
                phone: phoneNumber
            )
            return true
        } catch {
            self.error = error
            print("Sign in error: \(error)")
            return false
        }
    }

    /// Verify OTP code
    func verifyOTP(phone: String, token: String) async -> Bool {
        do {
            try await supabase.auth.verifyOTP(
                phone: phone,
                token: token,
                type: .sms
            )

            await checkAuthStatus()
            return true
        } catch {
            self.error = error
            print("OTP verification error: \(error)")
            return false
        }
    }

    /// Sign out
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            print("Sign out error: \(error)")
        }
    }

    /// Fetch current user profile
    private func fetchCurrentUser() async {
        do {
            guard let userId = try await supabase.auth.session.user.id.uuidString else {
                return
            }

            let response: User = try await supabase.database
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            currentUser = response
        } catch {
            print("Error fetching user: \(error)")
        }
    }
}

/// User model
struct User: Codable {
    let id: String
    let email: String?
    let phone: String?
    var fullName: String
    let role: String
    var personaType: String?
    var communicationPreference: String?
    var avatarUrl: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, email, phone, role
        case fullName = "full_name"
        case personaType = "persona_type"
        case communicationPreference = "communication_preference"
        case avatarUrl = "avatar_url"
        case isActive = "is_active"
    }
}
