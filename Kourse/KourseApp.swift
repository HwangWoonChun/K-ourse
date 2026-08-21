//
//  KourseApp.swift
//  Kourse
//
//  Created by lotte on 8/14/26.
//

import SwiftUI
import SwiftData
import FirebaseCore
import KakaoSDKCommon
import KakaoSDKAuth

@main
struct KourseApp: App {
    @StateObject private var authVM = AuthViewModel()

    init() {
        FirebaseApp.configure()
        KakaoSDK.initSDK(appKey: "baf253e85faaf9d218a8569693001ef5")
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(authVM)
                .onOpenURL { url in
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        AuthController.handleOpenUrl(url: url)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
