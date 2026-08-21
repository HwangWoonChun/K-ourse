//
//  GeocodingService.swift
//  Kourse
//

import Foundation

enum GeocodingError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           "잘못된 URL입니다."
        case .networkError(let e):  "네트워크 오류: \(e.localizedDescription)"
        case .decodingError(let e): "데이터 파싱 오류: \(e.localizedDescription)"
        }
    }
}

final class GeocodingService {
    static let shared = GeocodingService()

    private let restKey = "baf253e85faaf9d218a8569693001ef5"
    private let localBaseURL = "https://dapi.kakao.com"

    private lazy var headers: [String: String] = [
        "Authorization": "KakaoAK \(restKey)"
    ]

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - 좌표 → 행정구역명 (홈 화면 현위치 표시)
    func fetchRegionName(latitude: Double, longitude: Double) async throws -> String {
        var components = URLComponents(string: "\(localBaseURL)/v2/local/geo/coord2regioncode.json")
        components?.queryItems = [
            URLQueryItem(name: "x", value: String(longitude)),
            URLQueryItem(name: "y", value: String(latitude))
        ]

        guard let url = components?.url else { throw GeocodingError.invalidURL }
        let response: GeocodingRegionResponse = try await request(url: url)

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
            throw GeocodingError.networkError(error)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GeocodingError.decodingError(error)
        }
    }

}
