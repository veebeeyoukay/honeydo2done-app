import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var isOTPSent = false
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Logo/Header
                VStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("HoneyDo2Done")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Your home's personal assistant")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Phone number input
                if !isOTPSent {
                    VStack(spacing: 16) {
                        TextField("Phone Number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)

                        Button(action: sendOTP) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Send Code")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(phoneNumber.isEmpty || isLoading)
                    }
                } else {
                    // OTP verification
                    VStack(spacing: 16) {
                        Text("Enter the code sent to")
                            .font(.subheadline)
                        Text(phoneNumber)
                            .font(.headline)

                        TextField("Verification Code", text: $otpCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .multilineTextAlignment(.center)
                            .font(.title2)

                        Button(action: verifyOTP) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Verify")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(otpCode.isEmpty || isLoading)

                        Button("Use different number") {
                            isOTPSent = false
                            otpCode = ""
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }

                // Error message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()

                // Terms
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }

    private func sendOTP() {
        isLoading = true
        errorMessage = ""

        Task {
            let success = await authService.signInWithPhone(phoneNumber: phoneNumber)

            await MainActor.run {
                isLoading = false
                if success {
                    isOTPSent = true
                } else {
                    errorMessage = "Failed to send code. Please try again."
                }
            }
        }
    }

    private func verifyOTP() {
        isLoading = true
        errorMessage = ""

        Task {
            let success = await authService.verifyOTP(phone: phoneNumber, token: otpCode)

            await MainActor.run {
                isLoading = false
                if !success {
                    errorMessage = "Invalid code. Please try again."
                }
            }
        }
    }
}
