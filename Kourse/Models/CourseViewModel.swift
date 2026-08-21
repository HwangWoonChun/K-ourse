//
//  CourseViewModel.swift
//  Kourse

import Foundation
import Combine

struct CourseStep: Identifiable, Equatable {
    let id = UUID()
    let spot: TourSpot
    let routeToNext: RouteResult?   // 마지막 장소는 nil

    static func == (lhs: CourseStep, rhs: CourseStep) -> Bool {
        lhs.id == rhs.id
    }
}

enum LoadingStep: String {
    case location  = "현재 위치 확인 중..."
    case searching = "주변 장소 검색 중..."
    case routing   = "경로 계산 중..."
    case done      = "완료"
}

@MainActor
final class CourseViewModel: ObservableObject {
    @Published var steps: [CourseStep] = []
    @Published var totalDurationSeconds: Int = 0
    @Published var isLoading = false
    @Published var loadingStep: LoadingStep = .location
    @Published var errorMessage: String?

    private let tourAPI = TourAPIService.shared
    private let naverDir = NaverDirectionsService.shared

    func generateCourse(
        latitude: Double,
        longitude: Double,
        theme: TravelTheme,
        duration: TravelDuration,
        isIndoor: Bool
    ) async {
        isLoading = true
        errorMessage = nil
        steps = []

        do {
            // 1단계: 위치 확인
            loadingStep = .location
            try await Task.sleep(nanoseconds: 400_000_000)

            // 2단계: 장소 검색 — 필요 개수보다 넉넉하게 요청
            loadingStep = .searching
            let needed = duration.spotCount
            let spots = try await tourAPI.fetchCourseSpots(
                latitude: latitude,
                longitude: longitude,
                theme: theme,
                duration: duration,
                isIndoor: isIndoor,
                numOfRows: max(needed * 4, 20)  // 넉넉하게 가져온 뒤 앱에서 추림
            )

            guard !spots.isEmpty else {
                errorMessage = "주변에 추천할 장소가 없어요."
                isLoading = false
                return
            }

            // 필요 개수만큼 선택 (가져온 게 부족하면 있는 만큼)
            let selected = Array(spots.prefix(needed))

            // 3단계: 경로 계산
            loadingStep = .routing
            var courseSteps: [CourseStep] = []
            var total = 0

            for i in 0..<selected.count {
                let spot = selected[i]
                var routeToNext: RouteResult? = nil

                if i < selected.count - 1 {
                    let from = (lat: spot.mapY, lng: spot.mapX)
                    let to   = (lat: selected[i + 1].mapY, lng: selected[i + 1].mapX)

                    // Naver Directions로 실제 도로 경로 확보, 실패 시 직선 도보 추정
                    if let carRoute = try? await naverDir.fetchRoute(from: from, to: to) {
                        routeToNext = carRoute
                    } else {
                        routeToNext = naverDir.estimateWalkRoute(from: from, to: to)
                    }
                    total += routeToNext?.duration ?? 0
                }
                courseSteps.append(CourseStep(spot: spot, routeToNext: routeToNext))
            }

            total += selected.count * 50 * 60
            loadingStep = .done
            steps = courseSteps
            totalDurationSeconds = total

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    var totalDurationFormatted: String {
        let m = totalDurationSeconds / 60
        return m < 60 ? "\(m)분" : "\(m / 60)시간 \(m % 60)분"
    }

    // 미리보기/테스트용 Mock
    func loadMock(isIndoor: Bool) {
        let spots = isIndoor ? MockData.indoorSpots : MockData.outdoorSpots
        var courseSteps: [CourseStep] = []
        var total = spots.count * 50 * 60

        for i in 0..<spots.count {
            let spot = spots[i]
            var routeToNext: RouteResult? = nil
            if i < spots.count - 1 {
                let from = (lat: spot.mapY, lng: spot.mapX)
                let to   = (lat: spots[i + 1].mapY, lng: spots[i + 1].mapX)
                let walk = naverDir.estimateWalkRoute(from: from, to: to)
                routeToNext = walk
                total += walk.duration
            }
            courseSteps.append(CourseStep(spot: spot, routeToNext: routeToNext))
        }
        steps = courseSteps
        totalDurationSeconds = total
    }
}
