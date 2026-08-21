//
//  AuthViewModel.swift
//  Kourse
//

import SwiftUI
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import Combine
import KakaoSDKAuth
import KakaoSDKUser

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var displayName: String? = nil

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isLoggedIn = user != nil
            if user != nil {
                self?.displayName = UserDefaults.standard.string(forKey: "displayName")
            } else {
                self?.displayName = nil
                UserDefaults.standard.removeObject(forKey: "displayName")
            }
        }
    }

    deinit {
        if let handle = authStateListener {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Apple Sign In

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple 로그인 정보를 가져올 수 없습니다."
                return
            }
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            if let fullName = credential.fullName,
               let given = fullName.givenName {
                let family = fullName.familyName ?? ""
                let name = "\(family)\(given)"
                displayName = name
                UserDefaults.standard.set(name, forKey: "displayName")
            }
            signIn(with: firebaseCredential)

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Kakao Login

    func signInWithKakao() {
        isLoading = true

        // 카카오톡 앱으로 로그인 (없으면 웹으로 fallback)
        if UserApi.isKakaoTalkLoginAvailable() {
            UserApi.shared.loginWithKakaoTalk { [weak self] token, error in
                if let error {
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                    return
                }
                guard let accessToken = token?.accessToken else { return }
                self?.fetchKakaoNicknameAndCustomToken(accessToken: accessToken)
            }
        } else {
            UserApi.shared.loginWithKakaoAccount { [weak self] token, error in
                if let error {
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                    return
                }
                guard let accessToken = token?.accessToken else { return }
                self?.fetchKakaoNicknameAndCustomToken(accessToken: accessToken)
            }
        }
    }

    private func fetchKakaoNicknameAndCustomToken(accessToken: String) {
        UserApi.shared.me { [weak self] user, error in
            if let nickname = user?.kakaoAccount?.profile?.nickname {
                self?.displayName = nickname
                UserDefaults.standard.set(nickname, forKey: "displayName")
            }
            self?.fetchKakaoCustomToken(accessToken: accessToken)
        }
    }

    // 카카오 액세스 토큰 → Firebase Custom Token 교환
    // ⚠️ Cloud Functions 배포 후 URL을 실제 주소로 교체하세요
    private func fetchKakaoCustomToken(accessToken: String) {
        guard let url = URL(string: "https://us-central1-kourse-5c8b1.cloudfunctions.net/kakaoCustomToken") else {
            errorMessage = "서버 URL이 설정되지 않았습니다."
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["accessToken": accessToken])

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                   let customToken = json["firebaseToken"] {
                    try await Auth.auth().signIn(withCustomToken: customToken)
                } else {
                    errorMessage = "Custom Token을 받아올 수 없습니다."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        try? Auth.auth().signOut()
    }

    // MARK: - Private

    private func signIn(with credential: AuthCredential) {
        isLoading = true
        Task {
            do {
                try await Auth.auth().signIn(with: credential)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
