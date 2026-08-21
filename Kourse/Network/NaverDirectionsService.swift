//
//  NaverDirectionsService.swift
//  Kourse
//

import Foundation
import CoreLocation

final class NaverDirectionsService {
    static let shared = NaverDirectionsService()

    private let baseURL = "https://maps.apigw.ntruss.com/map-direction/v1/driving"
    private let keyId   = "8rq882lasj"
    private let secret  = "hhKBVnx4GFq3pCsOk7d4xsExkmfIpGodb3H3jxKd"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - 두 지점 간 차량 경로 (도로 좌표 포함)
    func fetchRoute(
        from origin: (lat: Double, lng: Double),
        to destination: (lat: Double, lng: Double)
    ) async throws -> RouteResult {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "start", value: "\(origin.lng),\(origin.lat)"),
            URLQueryItem(name: "goal",  value: "\(destination.lng),\(destination.lat)"),
            URLQueryItem(name: "option", value: "traoptimal")
        ]

        guard let url = components?.url else { throw NaverDirectionsError.invalidURL }

        var request = URLRequest(url: url)
        request.addValue(keyId,  forHTTPHeaderField: "X-NCP-APIGW-API-KEY-ID")
        request.addValue(secret, forHTTPHeaderField: "X-NCP-APIGW-API-KEY")

        let data: Data
        do {
            let (responseData, _) = try await session.data(for: request)
            data = responseData
        } catch {
            throw NaverDirectionsError.networkError(error)
        }

        let response: NaverDirectionsResponse
        do {
            response = try JSONDecoder().decode(NaverDirectionsResponse.self, from: data)
        } catch {
            throw NaverDirectionsError.decodingError(error)
        }

        guard response.code == 0,
              let routeInfo = response.route?.traoptimal?.first else {
            throw NaverDirectionsError.routeNotFound
        }

        // path: [[lng, lat], [lng, lat], ...]
        let path: [CLLocationCoordinate2D] = routeInfo.path.map {
            CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
        }

        let distanceM = routeInfo.summary.distance
        let durationSec = routeInfo.summary.duration / 1000  // ms → 초
        let durationMin = durationSec / 60

        return RouteResult(
            distance: distanceM,
            duration: durationSec,
            summary: "차량 \(durationMin)분",
            path: path
        )
    }

    // MARK: - 도보 추정 (거리 기반, 분속 80m) — 직선 path
    func estimateWalkRoute(
        from origin: (lat: Double, lng: Double),
        to destination: (lat: Double, lng: Double)
    ) -> RouteResult {
        let distanceM = haversine(from: origin, to: destination)
        let walkSec = Int(distanceM / 80.0 * 60.0)
        return RouteResult(
            distance: Int(distanceM),
            duration: walkSec,
            summary: "도보 \(walkSec / 60)분",
            path: [
                CLLocationCoordinate2D(latitude: origin.lat, longitude: origin.lng),
                CLLocationCoordinate2D(latitude: destination.lat, longitude: destination.lng)
            ]
        )
    }

    // MARK: - Haversine
    private func haversine(
        from: (lat: Double, lng: Double),
        to: (lat: Double, lng: Double)
    ) -> Double {
        let R = 6371000.0
        let lat1 = from.lat * .pi / 180, lat2 = to.lat * .pi / 180
        let dLat = (to.lat - from.lat) * .pi / 180
        let dLng = (to.lng - from.lng) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLng/2) * sin(dLng/2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

// MARK: - Error
enum NaverDirectionsError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case routeNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:             "잘못된 URL입니다."
        case .networkError(let e):    "네트워크 오류: \(e.localizedDescription)"
        case .decodingError(let e):   "데이터 파싱 오류: \(e.localizedDescription)"
        case .routeNotFound:          "경로를 찾을 수 없습니다."
        }
    }
}

// MARK: - Response Models
struct NaverDirectionsResponse: Codable {
    let code: Int
    let message: String?
    let route: NaverRouteSet?
}

struct NaverRouteSet: Codable {
    let traoptimal: [NaverRouteOption]?
}

struct NaverRouteOption: Codable {
    let summary: NaverRouteSummary
    let path: [[Double]]   // [[lng, lat], ...]
}

struct NaverRouteSummary: Codable {
    let distance: Int   // 미터
    let duration: Int   // 밀리초
}
