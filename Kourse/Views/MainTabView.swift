//
//  MainTabView.swift
//  Kourse
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var weatherVM = WeatherViewModel()
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(weatherVM: weatherVM)
                    .tag(0)

                MyCourseView()
                    .tag(1)

                ProfileView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            weatherVM.requestLocationAndLoad()
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 0 {
                weatherVM.requestLocationAndLoad() // 쿨다운 적용
            }
        }
    }
}

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {
    @Binding var selectedTab: Int

    private let items: [(icon: String, label: String)] = [
        ("house.fill", "홈"),
        ("map.fill", "나의코스"),
        ("person.fill", "프로필"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                Button {
                    selectedTab = i
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: items[i].icon)
                            .font(.system(size: 20))
                        Text(items[i].label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(selectedTab == i ? .kGreen : .kTabBarIcon)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            Color.kBackground
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
        )
    }
}

// MARK: - Placeholder Tabs

struct MyCourseView: View {
    var body: some View {
        ZStack {
            Color.kBackground.ignoresSafeArea()
            Text("나의 코스")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showLogoutAlert = false

    var body: some View {
        ZStack {
            Color.kBackground.ignoresSafeArea()

            VStack {
                Spacer()

                Text("프로필")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    showLogoutAlert = true
                } label: {
                    Text("로그아웃")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            Button("취소", role: .cancel) {}
            Button("로그아웃", role: .destructive) {
                authVM.signOut()
            }
        } message: {
            Text("정말 로그아웃 하시겠어요?")
        }
    }
}

#Preview {
    MainTabView()
}
