//
//  CourseResultView.swift
//  Kourse

import SwiftUI
import MapKit

// MARK: - CourseResultView

struct CourseResultView: View {
    @ObservedObject var vm: CourseViewModel
    let theme: TravelTheme
    let duration: TravelDuration
    @Environment(\.dismiss) private var dismiss

    // 지도 카메라 - 첫 장소 중심
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .top) {
            Color.kBackground.ignoresSafeArea()

            if vm.isLoading {
                loadingView
            } else if let err = vm.errorMessage {
                errorView(err)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        mapSection
                        infoHeader
                        spotList
                    }
                }
                .ignoresSafeArea(edges: .top)
            }

            // 상단 닫기 버튼
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.kTextPrimary)
                        .padding(10)
                        .background(Circle().fill(Color.white).shadow(color: .black.opacity(0.1), radius: 4))
                }
                .padding(.leading, 20)
                .padding(.top, 56)
                Spacer()
            }
        }
        .onAppear {
            updateCamera()
        }
        .onChange(of: vm.steps) { _, _ in
            updateCamera()
        }
    }

    // MARK: - 지도

    private var mapSection: some View {
        Map(position: $cameraPosition) {
            ForEach(Array(vm.steps.enumerated()), id: \.element.id) { index, step in
                Annotation(step.spot.title, coordinate: coordinate(for: step.spot)) {
                    SpotMapPin(index: index + 1, isFirst: index == 0, isLast: index == vm.steps.count - 1)
                }
            }

            // 장소 간 경로선
            if vm.steps.count > 1 {
                let coords = vm.steps.map { coordinate(for: $0.spot) }
                MapPolyline(coordinates: coords)
                    .stroke(Color.kGreen.opacity(0.7), lineWidth: 2.5)
            }
        }
        .frame(height: 300)
        .disabled(false)
    }

    // MARK: - 코스 요약 헤더

    private var infoHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text(theme.icon)
                    .font(.system(size: 20))
                Text("\(theme.rawValue) 코스")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.kTextPrimary)
                Spacer()
            }

            HStack(spacing: 12) {
                Label("\(vm.steps.count)곳", systemImage: "mappin.and.ellipse")
                Label(vm.totalDurationFormatted, systemImage: "clock")
                Label(duration.rawValue, systemImage: "figure.walk")
                Spacer()
            }
            .font(.system(size: 13))
            .foregroundColor(.kTextSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color.kBackground)
    }

    // MARK: - 장소 목록

    private var spotList: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.steps.enumerated()), id: \.element.id) { index, step in
                VStack(spacing: 0) {
                    SpotRow(index: index + 1, step: step)

                    // 이동 정보
                    if let route = step.routeToNext {
                        RouteConnector(route: route)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    // MARK: - 로딩 / 에러

    private var loadingView: some View {
        VStack(spacing: 0) {
            Spacer()

            // 스피너
            ProgressView()
                .scaleEffect(1.5)
                .tint(.kGreen)
                .padding(.bottom, 28)

            // 타이틀
            Text("코스를 만들고 있어요")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.kTextPrimary)
                .padding(.bottom, 10)

            // 현재 단계 메시지
            Text(vm.loadingStep.rawValue)
                .font(.system(size: 14))
                .foregroundColor(.kTextSecondary)
                .animation(.easeInOut, value: vm.loadingStep)
                .padding(.bottom, 36)

            // 단계 진행 바
            LoadingStepBar(currentStep: vm.loadingStep)
                .padding(.horizontal, 48)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.kTextSecondary)
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.kTextSecondary)
                .multilineTextAlignment(.center)
            Button("다시 시도") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.kGreen)
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private func coordinate(for spot: TourSpot) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: spot.mapY, longitude: spot.mapX)
    }

    private func updateCamera() {
        guard !vm.steps.isEmpty else { return }
        let coords = vm.steps.map { coordinate(for: $0.spot) }
        let region = MKCoordinateRegion(coordinates: coords) ?? MKCoordinateRegion(
            center: coords[0],
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        cameraPosition = .region(region)
    }
}

// MARK: - SpotMapPin

private struct SpotMapPin: View {
    let index: Int
    let isFirst: Bool
    let isLast: Bool

    private var color: Color {
        if isFirst { return .kGreen }
        if isLast  { return Color(hex: "#E05C5C") ?? .red }
        return Color(hex: "#5B8DD9") ?? .blue
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .shadow(color: color.opacity(0.4), radius: 4)
                Text("\(index)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            Image(systemName: "triangle.fill")
                .font(.system(size: 6))
                .foregroundColor(color)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
    }
}

// MARK: - SpotRow

private struct SpotRow: View {
    let index: Int
    let step: CourseStep

    private var typeLabel: String {
        switch step.spot.contentType {
        case .tourist:   return "관광지"
        case .culture:   return "문화시설"
        case .restaurant: return "맛집"
        case .shopping:  return "쇼핑"
        case .leisure:   return "레포츠"
        case .festival:  return "축제"
        case .accommodation: return "숙박"
        case .none:      return ""
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // 번호 인디케이터
            ZStack {
                Circle()
                    .fill(Color.kGreenLight)
                    .frame(width: 36, height: 36)
                Text("\(index)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.kGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.spot.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.kTextPrimary)

                HStack(spacing: 6) {
                    Text(typeLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.kGreen)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.kGreenLight)
                        .cornerRadius(6)

                    if !step.spot.address.isEmpty {
                        Text(step.spot.address)
                            .font(.system(size: 12))
                            .foregroundColor(.kTextSecondary)
                            .lineLimit(1)
                    }
                }

                // 체류 시간
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text("약 50분 체류")
                        .font(.system(size: 12))
                }
                .foregroundColor(.kTextSecondary)
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        )
    }
}

// MARK: - RouteConnector

private struct RouteConnector: View {
    let route: RouteResult

    private var icon: String {
        route.summary.contains("도보") ? "figure.walk" : "car.fill"
    }

    var body: some View {
        HStack(spacing: 8) {
            // 세로 점선
            Rectangle()
                .fill(Color.kGreen.opacity(0.3))
                .frame(width: 1.5)
                .frame(height: 36)
                .padding(.leading, 17)

            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.kGreen)

            Text(route.summary)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.kTextSecondary)

            Text("·")
                .foregroundColor(.kTextSecondary)

            Text(route.formattedDistance)
                .font(.system(size: 12))
                .foregroundColor(.kTextSecondary)

            Spacer()
        }
    }
}

// MARK: - LoadingStepBar

private struct LoadingStepBar: View {
    let currentStep: LoadingStep

    private let steps: [LoadingStep] = [.location, .searching, .routing]

    private func stepIndex(_ step: LoadingStep) -> Int {
        steps.firstIndex(of: step) ?? 0
    }

    private var progress: Double {
        let current = stepIndex(currentStep)
        return Double(current + 1) / Double(steps.count)
    }

    var body: some View {
        VStack(spacing: 10) {
            // 진행 바
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.kGreen.opacity(0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.kGreen)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 4)

            // 단계 라벨
            HStack {
                ForEach(steps, id: \.self) { step in
                    Text(stepLabel(step))
                        .font(.system(size: 11))
                        .foregroundColor(stepIndex(step) <= stepIndex(currentStep) ? .kGreen : .kTextSecondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func stepLabel(_ step: LoadingStep) -> String {
        switch step {
        case .location:  return "위치"
        case .searching: return "장소 검색"
        case .routing:   return "경로 계산"
        case .done:      return "완료"
        }
    }
}

// MARK: - MKCoordinateRegion 확장

private extension MKCoordinateRegion {
    init?(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return nil }
        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.max()! + lats.min()!) / 2,
            longitude: (lngs.max()! + lngs.min()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) * 1.5 + 0.01,
            longitudeDelta: (lngs.max()! - lngs.min()!) * 1.5 + 0.01
        )
        self.init(center: center, span: span)
    }
}

// MARK: - Preview

#Preview {
    let vm = CourseViewModel()
    let _ = { vm.loadMock(isIndoor: false) }()
    return CourseResultView(vm: vm, theme: .culture, duration: .halfDay)
}
