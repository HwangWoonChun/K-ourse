//
//  CourseResultView.swift
//  Kourse

import SwiftUI
import NMapsMap

// MARK: - CourseResultView

struct CourseResultView: View {
    @ObservedObject var vm: CourseViewModel
    let theme: TravelTheme
    let duration: TravelDuration
    @Environment(\.dismiss) private var dismiss

    // 지도 카메라 업데이트 트리거
    @State private var mapUpdateTrigger: UUID = UUID()
    @State private var isAIExpanded = false

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
                        aiAnalysisSection
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
            mapUpdateTrigger = UUID()
        }
        .onChange(of: vm.steps) { _, _ in
            mapUpdateTrigger = UUID()
        }
    }

    // MARK: - 지도

    private var mapSection: some View {
        NaverMapView(steps: vm.steps, updateTrigger: mapUpdateTrigger)
            .frame(height: 300)
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

    // MARK: - AI 분석 섹션

    @ViewBuilder
    private var aiAnalysisSection: some View {
        if vm.isGeneratingExplanation || vm.courseExplanation != nil {
            VStack(spacing: 0) {
                // 헤더 (토글 버튼)
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isAIExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.purple)
                        Text("AI 분석")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.kTextPrimary)
                        Spacer()
                        if vm.isGeneratingExplanation {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: isAIExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.kTextSecondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.purple.opacity(0.06))
                }
                .buttonStyle(.plain)
                .disabled(vm.isGeneratingExplanation)

                // 펼쳐진 내용
                if isAIExpanded, let text = vm.courseExplanation {
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundColor(.kTextPrimary)
                        .lineSpacing(5)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.04))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider()
            }
            .onChange(of: vm.courseExplanation) { _, newVal in
                if newVal != nil { isAIExpanded = true }
            }
        }
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


// MARK: - NaverMapView

private struct NaverMapView: UIViewRepresentable {
    let steps: [CourseStep]
    let updateTrigger: UUID

    func makeUIView(context: Context) -> NMFMapView {
        let mapView = NMFMapView()
        mapView.mapType = .basic
        mapView.isScrollGestureEnabled = true
        mapView.isZoomGestureEnabled = true
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: NMFMapView, context: Context) {
        context.coordinator.clearOverlays()
        guard !steps.isEmpty else { return }

        let spotLatLngs: [NMGLatLng] = steps.map { NMGLatLng(lat: $0.spot.mapY, lng: $0.spot.mapX) }

        // 마커
        for (index, latlng) in spotLatLngs.enumerated() {
            let marker = NMFMarker(position: latlng)
            marker.captionText = "\(index + 1)"
            marker.captionTextSize = 13
            marker.captionColor = .white
            marker.captionHaloColor = markerColor(index: index, total: steps.count)
            marker.iconTintColor = markerColor(index: index, total: steps.count)
            marker.width = 30
            marker.height = 38
            marker.zIndex = 10
            marker.mapView = mapView
            context.coordinator.markers.append(marker)
        }

        // 경로 폴리라인
        var allPathLatLngs: [NMGLatLng] = []
        for step in steps {
            guard let route = step.routeToNext, !route.path.isEmpty else { continue }
            let routeLatLngs = route.path.map { NMGLatLng(lat: $0.latitude, lng: $0.longitude) }
            allPathLatLngs.append(contentsOf: routeLatLngs)
            if let polyline = NMFPolylineOverlay(routeLatLngs) {
                polyline.color = UIColor(red: 0.27, green: 0.67, blue: 0.42, alpha: 0.85)
                polyline.width = 4
                polyline.mapView = mapView
                context.coordinator.polylines.append(polyline)
            }
        }

        // 카메라: 레이아웃이 끝난 뒤 적용해야 bounds 계산이 정확함
        let allLatLngs = spotLatLngs + allPathLatLngs
        context.coordinator.pendingBoundsLatLngs = allLatLngs
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak coordinator = context.coordinator] in
            guard let coordinator, let mapView = coordinator.mapView,
                  let latlngs = coordinator.pendingBoundsLatLngs,
                  !latlngs.isEmpty else { return }
            coordinator.pendingBoundsLatLngs = nil

            // bounds를 직접 계산 (NMGLatLngBounds 생성자 안전하게)
            let lats = latlngs.map(\.lat)
            let lngs = latlngs.map(\.lng)
            let sw = NMGLatLng(lat: lats.min()!, lng: lngs.min()!)
            let ne = NMGLatLng(lat: lats.max()!, lng: lngs.max()!)
            let bounds = NMGLatLngBounds(southWest: sw, northEast: ne)

            let cameraUpdate = NMFCameraUpdate(fit: bounds, padding: 60)
            cameraUpdate.animation = .easeIn
            cameraUpdate.animationDuration = 0.4
            mapView.moveCamera(cameraUpdate)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func markerColor(index: Int, total: Int) -> UIColor {
        if index == 0 { return UIColor(red: 0.27, green: 0.67, blue: 0.42, alpha: 1) }
        if index == total - 1 { return UIColor(red: 0.88, green: 0.36, blue: 0.36, alpha: 1) }
        return UIColor(red: 0.36, green: 0.55, blue: 0.85, alpha: 1)
    }

    class Coordinator: NSObject {
        weak var mapView: NMFMapView?
        var markers: [NMFMarker] = []
        var polylines: [NMFPolylineOverlay] = []
        var pendingBoundsLatLngs: [NMGLatLng]?

        func clearOverlays() {
            markers.forEach { $0.mapView = nil }
            markers = []
            polylines.forEach { $0.mapView = nil }
            polylines = []
            pendingBoundsLatLngs = nil
        }
    }
}

// MARK: - Preview

#Preview {
    let vm = CourseViewModel()
    let _ = { vm.loadMock(isIndoor: false) }()
    return CourseResultView(vm: vm, theme: .culture, duration: .halfDay)
}
