//
//  WeatherAPIService.swift
//  Kourse
//

import Foundation

enum WeatherAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(code: String, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "잘못된 URL입니다."
        case .networkError(let e): "네트워크 오류: \(e.localizedDescription)"
        case .decodingError(let e): "데이터 파싱 오류: \(e.localizedDescription)"
        case .apiError(_, let msg): "API 오류: \(msg)"
        }
    }
}

final class WeatherAPIService {
    static let shared = WeatherAPIService()

    private let baseURL = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0"
    // 퍼센트 인코딩된 서비스키 (+ → %2B, / → %2F, = → %3D)
    private let apiKey = "qt0qwtuNHoBUpLF2%2Byslv%2FwKRU2Z8JgUhi7pRG7B43Qc0g88IrOxiyaUQPVX5RyCqgRUAojQjmby3IfGbSB1dA%3D%3D"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - 현재 날씨 실황 (코스 생성 시 사용)
    func fetchCurrentWeather(latitude: Double, longitude: Double) async throws -> WeatherCondition {
        let grid = GridConverter.convert(latitude: latitude, longitude: longitude)
        let (date, time) = currentBaseDateTime(minuteOffset: 40) // 실황은 40분 전 기준

        let params: [String: String] = [
            "base_date": date,
            "base_time": time,
            "nx": String(grid.nx),
            "ny": String(grid.ny),
            "numOfRows": "10",
            "pageNo": "1"
        ]

        let items = try await request(endpoint: "getUltraSrtNcst", params: params)
        return WeatherCondition(items: items)
    }

    // MARK: - 초단기 예보 (1~6시간, 실시간 변수 대응)
    func fetchShortForecast(latitude: Double, longitude: Double) async throws -> WeatherCondition {
        let grid = GridConverter.convert(latitude: latitude, longitude: longitude)
        let (date, time) = currentBaseDateTime(minuteOffset: 45) // 초단기는 45분 전 기준

        let params: [String: String] = [
            "base_date": date,
            "base_time": time,
            "nx": String(grid.nx),
            "ny": String(grid.ny),
            "numOfRows": "60",
            "pageNo": "1"
        ]

        let items = try await request(endpoint: "getUltraSrtFcst", params: params)
        // 가장 가까운 시간대 예보만 사용
        let nearest = nearestForecastItems(from: items)
        return WeatherCondition(items: nearest)
    }

    // MARK: - 단기 예보 (3일, 코스 결과 화면)
    func fetchDailyForecast(latitude: Double, longitude: Double) async throws -> [WeatherCondition] {
        let grid = GridConverter.convert(latitude: latitude, longitude: longitude)
        let (date, time) = villageForecastBaseTime()

        let params: [String: String] = [
            "base_date": date,
            "base_time": time,
            "nx": String(grid.nx),
            "ny": String(grid.ny),
            "numOfRows": "300",
            "pageNo": "1"
        ]

        let items = try await request(endpoint: "getVilageFcst", params: params)
        return groupByHour(items: items)
    }

    // MARK: - 날씨 변화 감지 (내비게이션 중 폴링)
    func detectWeatherChange(
        latitude: Double,
        longitude: Double,
        currentCondition: WeatherCondition
    ) async throws -> Bool {
        let newCondition = try await fetchShortForecast(latitude: latitude, longitude: longitude)
        // 실내/실외 추천이 바뀌면 변화 감지
        return newCondition.isIndoorRecommended != currentCondition.isIndoorRecommended
    }

    // MARK: - 내부 유틸

    private func request(endpoint: String, params: [String: String]) async throws -> [WeatherItem] {
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "serviceKey", value: apiKey),
            URLQueryItem(name: "dataType", value: "JSON"),
            URLQueryItem(name: "numOfRows", value: "10"),
            URLQueryItem(name: "pageNo", value: "1")
        ]
        queryItems += params.map { URLQueryItem(name: $0.key, value: $0.value) }
        components?.queryItems = queryItems

        // apiKey는 이미 퍼센트 인코딩된 값 → percentEncodedQueryItems로 이중인코딩 방지
        let nonKeyItems = queryItems.filter { $0.name != "serviceKey" }
        components?.queryItems = nonKeyItems
        let base = components?.url?.absoluteString ?? ""
        let urlStr = base + (base.contains("?") ? "&" : "?") + "serviceKey=\(apiKey)"
        guard let url = URL(string: urlStr) else { throw WeatherAPIError.invalidURL }

        #if DEBUG
        print("[Weather] URL: \(url)")
        #endif

        let data: Data
        do {
            let (responseData, _) = try await session.data(from: url)
            data = responseData
        } catch {
            throw WeatherAPIError.networkError(error)
        }

        #if DEBUG
        print("[Weather] Raw response: \(String(data: data, encoding: .utf8) ?? "<binary>")")
        #endif

        do {
            let decoded = try JSONDecoder().decode(WeatherResponse.self, from: data)
            let header = decoded.response.header
            guard header.resultCode == "00" else {
                throw WeatherAPIError.apiError(code: header.resultCode, message: header.resultMsg)
            }
            return decoded.response.body?.items?.item ?? []
        } catch let e as WeatherAPIError {
            throw e
        } catch {
            throw WeatherAPIError.decodingError(error)
        }
    }

    // 기상청 실황 기준시각: 현재 시각에서 minuteOffset 이전으로 내림
    private func currentBaseDateTime(minuteOffset: Int) -> (date: String, time: String) {
        var date = Date().addingTimeInterval(-Double(minuteOffset * 60))
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        // 분 단위 내림 (0분 기준)
        date = date.addingTimeInterval(-Double(minute * 60))

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyyMMdd"
        let dateStr = formatter.string(from: date)
        formatter.dateFormat = "HHmm"
        let timeStr = formatter.string(from: date)
        return (dateStr, timeStr)
    }

    // 단기예보 발표시각: 0200, 0500, 0800, 1100, 1400, 1700, 2000, 2300
    private func villageForecastBaseTime() -> (date: String, time: String) {
        let baseTimes = [2, 5, 8, 11, 14, 17, 20, 23]
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        let currentHour = minute < 10 ? hour - 1 : hour
        let baseHour = baseTimes.last(where: { $0 <= currentHour }) ?? 23

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        if baseHour == 23 && currentHour < 2 {
            components.day = (components.day ?? 1) - 1
        }
        components.hour = baseHour
        let baseDate = calendar.date(from: components) ?? now

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyyMMdd"
        let dateStr = formatter.string(from: baseDate)
        let timeStr = String(format: "%02d00", baseHour)
        return (dateStr, timeStr)
    }

    // 초단기예보 중 현재와 가장 가까운 시간대 아이템 추출
    private func nearestForecastItems(from items: [WeatherItem]) -> [WeatherItem] {
        guard let firstTime = items.first?.fcstTime else { return items }
        return items.filter { $0.fcstTime == firstTime }
    }

    // 단기예보 시간대별 그룹화
    private func groupByHour(items: [WeatherItem]) -> [WeatherCondition] {
        let grouped = Dictionary(grouping: items) { "\($0.fcstDate ?? "")\($0.fcstTime ?? "")" }
        return grouped.keys.sorted().prefix(12).compactMap { key in
            guard let group = grouped[key] else { return nil }
            return WeatherCondition(items: group)
        }
    }
}
