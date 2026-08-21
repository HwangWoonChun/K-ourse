//
//  TourAPIService.swift
//  Kourse
//

import Foundation

enum TourAPIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "TourAPI 키가 설정되지 않았습니다."
        case .invalidURL: "잘못된 URL입니다."
        case .networkError(let e): "네트워크 오류: \(e.localizedDescription)"
        case .decodingError(let e): "데이터 파싱 오류: \(e.localizedDescription)"
        case .apiError(_, let msg): "API 오류: \(msg)"
        }
    }
}

enum TravelTheme: String, CaseIterable {
    case nature = "자연"
    case culture = "문화"
    case food = "맛집"
    case activity = "액티비티"

    // 테마별 contentTypeId 필터
    var contentTypeIds: [ContentType] {
        switch self {
        case .nature:    [.tourist, .leisure]
        case .culture:   [.culture, .festival]
        case .food:      [.restaurant, .shopping]
        case .activity:  [.leisure, .tourist]
        }
    }
}

enum TravelDuration: String, CaseIterable {
    case twoHours = "2시간"
    case halfDay = "반나절"
    case fullDay = "하루"

    var spotCount: Int {
        switch self {
        case .twoHours: 2
        case .halfDay:  3
        case .fullDay:  5
        }
    }
}

final class TourAPIService {
    static let shared = TourAPIService()

    private let baseURL = "https://apis.data.go.kr/B551011/KorService2"
    // API 키는 키 발급 후 여기에 입력하세요. (또는 Secret.xcconfig 연동 후 Bundle에서 읽어오기)
    // 공공데이터포털 인코딩 키 (percent-encoded 그대로 사용)
    private let apiKey = "qt0qwtuNHoBUpLF2%2Byslv%2FwKRU2Z8JgUhi7pRG7B43Qc0g88IrOxiyaUQPVX5RyCqgRUAojQjmby3IfGbSB1dA%3D%3D"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - 위치 기반 주변 관광지 조회
    func fetchNearbySpots(
        latitude: Double,
        longitude: Double,
        radius: Int = 5000,
        contentTypeId: ContentType? = nil,
        numOfRows: Int = 20,
        pageNo: Int = 1
    ) async throws -> [TourSpot] {
        var params: [String: String] = [
            "mapX": String(longitude),
            "mapY": String(latitude),
            "radius": String(radius),
            "numOfRows": String(numOfRows),
            "pageNo": String(pageNo),
            "arrange": "E"  // 거리순 정렬
        ]
        if let typeId = contentTypeId {
            params["contentTypeId"] = typeId.rawValue
        }

        return try await request(endpoint: "locationBasedList2", params: params)
    }

    // MARK: - 날씨에 따른 실내/실외 코스 생성
    func fetchCourseSpots(
        latitude: Double,
        longitude: Double,
        theme: TravelTheme,
        duration: TravelDuration,
        isIndoor: Bool,
        numOfRows: Int = 20
    ) async throws -> [TourSpot] {
        let targetTypes = theme.contentTypeIds.filter { $0.isIndoor == isIndoor }
        let typesToFetch = targetTypes.isEmpty ? theme.contentTypeIds : targetTypes

        var results: [TourSpot] = []

        for typeId in typesToFetch {
            let spots = try await fetchNearbySpots(
                latitude: latitude,
                longitude: longitude,
                radius: 10000,          // 반경 10km로 확대
                contentTypeId: typeId,
                numOfRows: numOfRows
            )
            results.append(contentsOf: spots)
        }

        // 중복 제거 후 거리순 정렬 — 개수 제한은 ViewModel에서 처리
        let unique = Array(Dictionary(grouping: results, by: \.id).compactMapValues(\.first).values)
        return unique.sorted { ($0.distance ?? 0) < ($1.distance ?? 0) }
    }

    // MARK: - 키워드 검색 (대체 장소 추천)
    func searchKeyword(
        keyword: String,
        contentTypeId: ContentType? = nil,
        numOfRows: Int = 10
    ) async throws -> [TourSpot] {
        var params: [String: String] = [
            "keyword": keyword,
            "numOfRows": String(numOfRows),
            "arrange": "A"
        ]
        if let typeId = contentTypeId {
            params["contentTypeId"] = typeId.rawValue
        }
        return try await request(endpoint: "searchKeyword2", params: params)
    }

    // MARK: - 장소 공통 상세 정보
    func fetchDetail(contentId: String) async throws -> TourSpotCommon? {
        let params: [String: String] = [
            "contentId": contentId,
            "defaultYN": "Y",
            "firstImageYN": "Y",
            "areacodeYN": "Y",
            "addrinfoYN": "Y",
            "mapinfoYN": "Y",
            "overviewYN": "Y"
        ]
        let results: [TourSpotCommon] = try await request(endpoint: "detailCommon2", params: params)
        return results.first
    }

    // MARK: - 장소 소개 정보 (운영시간, 휴무일)
    func fetchIntro(contentId: String, contentTypeId: ContentType) async throws -> TourSpotIntro? {
        let params: [String: String] = [
            "contentId": contentId,
            "contentTypeId": contentTypeId.rawValue
        ]
        let results: [TourSpotIntro] = try await request(endpoint: "detailIntro2", params: params)
        return results.first
    }

    // MARK: - 이미지 갤러리
    func fetchImages(contentId: String) async throws -> [TourSpotImage] {
        let params: [String: String] = [
            "contentId": contentId,
            "imageYN": "Y",
            "subImageYN": "Y"
        ]
        return try await request(endpoint: "detailImage2", params: params)
    }

    // MARK: - 행사/축제 조회
    func fetchFestivals(
        latitude: Double,
        longitude: Double,
        startDate: Date = Date()
    ) async throws -> [TourSpot] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let params: [String: String] = [
            "mapX": String(longitude),
            "mapY": String(latitude),
            "radius": "10000",
            "eventStartDate": formatter.string(from: startDate),
            "numOfRows": "10",
            "arrange": "E"
        ]
        return try await request(endpoint: "searchFestival2", params: params)
    }

    // MARK: - 공통 요청
    private func request<T: Codable>(
        endpoint: String,
        params: [String: String]
    ) async throws -> [T] {
        guard !apiKey.isEmpty else {
            return []
        }

        var components = URLComponents(string: "\(baseURL)/\(endpoint)")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "MobileOS", value: "IOS"),
            URLQueryItem(name: "MobileApp", value: "Kourse"),
            URLQueryItem(name: "_type", value: "json")
        ]
        queryItems += params.map { URLQueryItem(name: $0.key, value: $0.value) }
        components?.queryItems = queryItems

        // serviceKey는 이미 percent-encoded 상태이므로 직접 삽입 (이중 인코딩 방지)
        guard var url = components?.url else { throw TourAPIError.invalidURL }
        let separator = url.query == nil ? "?" : "&"
        url = URL(string: url.absoluteString + "\(separator)serviceKey=\(apiKey)") ?? url

        let data: Data
        do {
            let (responseData, _) = try await session.data(from: url)
            data = responseData
        } catch {
            throw TourAPIError.networkError(error)
        }

        do {
            // 디버그: 응답 원문 출력
            if let raw = String(data: data, encoding: .utf8) {
                print("🌐 TourAPI 응답:\n\(raw.prefix(500))")
            }
            let decoded = try JSONDecoder().decode(TourAPIResponse<T>.self, from: data)
            let header = decoded.response.header
            guard header.resultCode == "0000" else {
                throw TourAPIError.apiError(code: header.resultCode, message: header.resultMsg)
            }
            return decoded.response.body.items?.item ?? []
        } catch let error as TourAPIError {
            throw error
        } catch {
            throw TourAPIError.decodingError(error)
        }
    }
}
