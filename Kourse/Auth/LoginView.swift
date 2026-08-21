//
//  LoginView.swift
//  Kourse
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(red: 0.13, green: 0.18, blue: 0.30)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 10) {
                    HStack(spacing: 0) {
                        Text("k")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(.white)
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.85, green: 0.15, blue: 0.20))
                                .frame(width: 11, height: 11)
                                .offset(y: -7)
                        }
                        Text("ourse")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text("여행은 계획대로 되지 않으니까")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .kerning(0.5)
                }

                Spacer()

                // 로그인 버튼들
                VStack(spacing: 12) {
                    // 카카오 로그인
                    KakaoLoginButton {
                        authVM.signInWithKakao()
                    }

                    // 애플 로그인
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = authVM.prepareAppleSignIn()
                    } onCompletion: { result in
                        authVM.handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // 에러 메시지
                if let error = authVM.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

                Text("로그인하면 서비스 이용약관 및 개인정보 처리방침에 동의하게 됩니다.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }

            // 로딩
            if authVM.isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
            }
        }
        .onChange(of: authVM.isLoggedIn) { _, loggedIn in
            if loggedIn { dismiss() }
        }
    }
}

// MARK: - 카카오 로그인 버튼

private struct KakaoLoginButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.fill")
                    .font(.system(size: 17))
                    .foregroundColor(.black.opacity(0.85))
                Text("카카오로 계속하기")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(red: 1.0, green: 0.90, blue: 0.0))
            .cornerRadius(14)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
