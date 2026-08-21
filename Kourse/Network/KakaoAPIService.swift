//
//  KakaoAPIService.swift
//  Kourse
//

import Foundation

enum KakaoAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case routeNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: "잘못된 URL입니다."
        case .networkError(let e): "네트워크 오류: \(e.localizedDescription)"
        case .decodingError(let e): "데이터 파싱 오류: \(e.localizedDescription)"
        case .routeNotFound: "경로를 찾을 수 없습니다."
        }
    }
}

final class KakaoAPIService {
    static let shared = KakaoAPIService()

    private let restKey = "baf253e85faaf9d218a8569693001ef5"
    private let localBaseURL = "https://dapi.kakao.com"
    private let naviBaseURL  = "https://apis-navi.kakaomobility.com"

    private lazy var headers: [String: String] = [
        "Authorization": "KakaoAK \(restKey)"
    ]

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - 두 장소 간 경로/소요시간 (차량)
    func fetchRoute(
        from origin: (lat: Double, lng: Double),
        to destination: (lat: Double, lng: Double)
    ) async throws -> RouteResult {
        var components = URLComponents(string: "\(naviBaseURL)/v1/directions")
        components?.queryItems = [
            URLQueryItem(name: "origin", value: "\(origin.lng),\(origin.lat)"),
            URLQueryItem(name: "destination", value: "\(destination.lng),\(destination.lat)"),
            URLQueryItem(name: "priority", value: "RECOMMEND")
        ]

        guard let url = components?.url else { throw KakaoAPIError.invalidURL }
        let response: KakaoDirectionsResponse = try await request(url: url)

        guard let summary = response.routes.first(where: { $0.resultCode == 0 })?.summary else {
            throw KakaoAPIError.routeNotFound
        }

        return RouteResult(
            distance: summary.distance,
            duration: summary.duration,
            summary: "차량 \(summary.duration / 60)분"
        )
    }

    // MARK: - 도보 소요시간 추정 (거리 기반, 분속 80m)
    func estimateWalkDuration(
        from origin: (lat: Double, lng: Double),
        to destination: (lat: Double, lng: Double)
    ) -> RouteResult {
        let distanceM = haversineDistance(from: origin, to: destination)
        let walkSeconds = Int(distanceM / 80.0 * 60.0) // 분속 80m
        return RouteResult(
            distance: Int(distanceM),
            duration: walkSeconds,
            summary: "도보 \(walkSeconds / 60)분"
        )
    }

    // MARK: - 코스 전체 소요시간 계산
    func calculateCourseDuration(spots: [TourSpot]) async throws -> Int {
        var totalSeconds = 0
        for i in 0..<spots.count - 1 {
            let from = (lat: spots[i].mapY, lng: spots[i].mapX)
            let to   = (lat: spots[i+1].mapY, lng: spots[i+1].mapX)
            let dist = haversineDistance(from: from, to: to)

            if dist < 1000 {
                // 1km 미만은 도보
                totalSeconds += estimateWalkDuration(from: from, to: to).duration
            } else {
                let route = try await fetchRoute(from: from, to: to)
                totalSeconds += route.duration
            }
        }
        // 장소당 평균 체류 시간 (관광지 60분, 식당 45분)
        totalSeconds += spots.count * 50 * 60
        return totalSeconds
    }

    // MARK: - 좌표 → 행정구역명 (홈 화면 현위치 표시)
    func fetchRegionName(latitude: Double, longitude: Double) async throws -> String {
        var components = URLComponents(string: "\(localBaseURL)/v2/local/geo/coord2regioncode.json")
        components?.queryItems = [
            URLQueryItem(name: "x", value: String(longitude)),
            URLQueryItem(name: "y", value: String(latitude))
        ]

        guard let url = components?.url else { throw KakaoAPIError.invalidURL }
        let response: KakaoRegionResponse = try await request(url: url)

        // H(법정동) 타입 우선, 없으면 B(행정동)
        let doc = response.documents.first(where: { $0.regionType == "H" })
               ?? response.documents.first
        guard let doc else { return "현재 위치" }

        let parts = [doc.region1DepthName, doc.region2DepthName, doc.region3DepthName]
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    // MARK: - 공통 요청
    private func request<T: Decodable>(url: URL) async throws -> T {
        var urlRequest = URLRequest(url: url)
        headers.forEach { urlRequest.addValue($0.value, forHTTPHeaderField: $0.key) }

        let data: Data
        do {
            let (responseData, _) = try await session.data(for: urlRequest)
            data = responseData
        } catch {
            throw KakaoAPIError.networkError(error)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw KakaoAPIError.decodingError(error)
        }
    }

    // 두 좌표 간 직선 거리 (m), Haversine 공식
    private func haversineDistance(
        from: (lat: Double, lng: Double),
        to: (lat: Double, lng: Double)
    ) -> Double {
        let R = 6371000.0
        let lat1 = from.lat * .pi / 180
        let lat2 = to.lat  * .pi / 180
        let dLat = (to.lat - from.lat) * .pi / 180
        let dLng = (to.lng - from.lng) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2)
              + cos(lat1) * cos(lat2) * sin(dLng/2) * sin(dLng/2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
