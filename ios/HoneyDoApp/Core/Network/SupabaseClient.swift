import Foundation
import Supabase

/// Singleton Supabase client for the application
class SupabaseClientManager {
    static let shared = SupabaseClientManager()

    let client: SupabaseClient

    private init() {
        // Load configuration
        guard let url = URL(string: Config.supabaseURL) else {
            fatalError("Invalid Supabase URL")
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Config.supabaseAnonKey,
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(
                    schema: "public"
                ),
                auth: SupabaseClientOptions.AuthOptions(
                    autoRefreshToken: true,
                    persistSession: true
                )
            )
        )
    }
}

/// Configuration (replace with Config.xcconfig or environment variables)
struct Config {
    static let supabaseURL = "https://your-project.supabase.co"
    static let supabaseAnonKey = "your-anon-key"
}
