//
//  HomeView.swift
//  Kourse
//

import SwiftUI

// MARK: - Extensions for existing enums

extension TravelTheme {
    var icon: String {
        switch self {
        case .nature:   return "🌿"
        case .culture:  return "🏛"
        case .food:     return "🍜"
        case .activity: return "🔧"
        }
    }
}

extension TravelDuration {
    var displayLabel: String {
        switch self {
        case .twoHours: return "짧은 코스"
        case .halfDay:  return "반나절 코스"
        case .fullDay:  return "하루 코스"
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @ObservedObject var weatherVM: WeatherViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedDuration: TravelDuration = .halfDay
    @State private var selectedThemes: Set<TravelTheme> = [.culture]
    @State private var showLogin = false
    @State private var showLocationAlert = false
    @State private var showCourseResult = false
    @StateObject private var courseVM = CourseViewModel()



    private var isRainy: Bool {
        weatherVM.condition?.precipitation.isWet ?? false
    }

    private var headlineText: String {
        isRainy
            ? "갑자기 비가 와도\n걱정하지 마세요."
            : "오늘 날씨, 나들이하기\n딱 좋은 날이에요."
    }

    private var ctaLabel: String {
        guard authVM.isLoggedIn else { return "로그인하러 가기" }
        return isRainy ? "실내 코스 생성하기" : "코스 생성하기"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.kBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top Bar ──────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.kTextSecondary)
                            Text(weatherVM.locationName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.kTextPrimary)
                        }
                        if let name = authVM.displayName {
                            Text("\(name)님")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.kTextSecondary)
                        }
                    }

                    Spacer()

                    if weatherVM.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let cond = weatherVM.condition {
                        WeatherBadge(condition: cond)
                    } else if !weatherVM.isLoading {
                        Button {
                            weatherVM.requestLocationAndLoad()
                        } label: {
                            Text("날씨를 불러오지 못했어요 ↺")
                                .font(.system(size: 12))
                                .foregroundColor(.kTextSecondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)

                // ── Headline ─────────────────────────────────────────
                Text(headlineText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.kTextPrimary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                // ── Duration Selector ─────────────────────────────────
                SectionLabel("여행 가능 시간")
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                HStack(spacing: 8) {
                    ForEach(TravelDuration.allCases, id: \.self) { d in
                        DurationChip(
                            title: d.displayLabel,
                            isSelected: selectedDuration == d
                        ) {
                            selectedDuration = d
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                // ── Theme Selector ────────────────────────────────────
                SectionLabel("테마 선택")
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                let themes = TravelTheme.allCases
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(themes, id: \.self) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: selectedThemes.contains(theme)
                        ) {
                            if selectedThemes.contains(theme) {
                                if selectedThemes.count > 1 { selectedThemes.remove(theme) }
                            } else {
                                selectedThemes.insert(theme)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                // ── CTA Button ────────────────────────────────────────
                Button {
                    if authVM.isLoggedIn {
                        if weatherVM.isLocationAuthorized {
                            Task {
                                showCourseResult = true
                                await courseVM.generateCourse(
                                    latitude: weatherVM.latitude,
                                    longitude: weatherVM.longitude,
                                    theme: selectedThemes.first ?? .culture,
                                    duration: selectedDuration,
                                    isIndoor: isRainy
                                )
                            }
                        } else {
                            showLocationAlert = true
                        }
                    } else {
                        showLogin = true
                    }
                } label: {
                    Text(ctaLabel)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.kGreen)
                        .cornerRadius(14)
                }
                .alert("위치 권한 필요", isPresented: $showLocationAlert) {
                    Button("취소", role: .cancel) {}
                    Button("설정으로 이동") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } message: {
                    Text("코스 생성을 위해 위치 권한이 필요합니다.\n설정에서 위치 접근을 허용해주세요.")
                }
                .padding(.horizontal, 24)
                .sheet(isPresented: $showLogin) {
                    LoginView()
                        .environmentObject(authVM)
                }
                .fullScreenCover(isPresented: $showCourseResult) {
                    CourseResultView(
                        vm: courseVM,
                        theme: selectedThemes.first ?? .culture,
                        duration: selectedDuration
                    )
                }
            }
        }
    }
}

// MARK: - WeatherBadge

private struct WeatherBadge: View {
    let condition: WeatherCondition

    private var iconName: String { condition.weatherIcon.name }
    private var iconColor: Color {
        Color(hex: condition.weatherIcon.colorHex) ?? .orange
    }
    private var temperature: Int { Int(condition.temperature.rounded()) }
    private var rainfall: Double { condition.rainfallMM }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 13))
                .foregroundColor(iconColor)

            Text("\(temperature)°")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.kTextPrimary)

            if rainfall > 0 {
                Divider()
                    .frame(height: 10)

                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#5B8DD9"))
                    Text(rainfallLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.kTextPrimary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    private var rainfallLabel: String {
        rainfall < 1 ? "1mm 미만" : String(format: "%.1fmm", rainfall)
    }
}

// MARK: - Color hex init


// MARK: - Sub-components

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.kTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DurationChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .kTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.kGreen : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.clear : Color.black.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

private struct ThemeCard: View {
    let theme: TravelTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(theme.icon)
                    .font(.system(size: 18))
                Text(theme.rawValue)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.kTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.kGreenLight : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.kGreen.opacity(0.5) : Color.black.opacity(0.07),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
