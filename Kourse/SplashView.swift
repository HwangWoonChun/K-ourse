//
//  SplashView.swift
//  Kourse
//

import SwiftUI

struct SplashView: View {
    @State private var isActive = false

    var body: some View {
        if isActive {
            MainTabView()
        } else {
            ZStack {
                Color(red: 0.13, green: 0.18, blue: 0.30)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    // Logo
                    HStack(spacing: 0) {
                        Text("k")
                            .font(.system(size: 36, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.85, green: 0.15, blue: 0.20))
                                .frame(width: 10, height: 10)
                                .offset(y: -6)
                            Text("·")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(.clear)
                        }
                        Text("ourse")
                            .font(.system(size: 36, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                    }

                    // Tagline
                    Text("여행은 계획대로 되지 않으니까")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .kerning(0.5)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
