//
//  WeatherModel.swift
//  Kourse
//

import Foundation

// 기상청 카테고리 코드
enum WeatherCategory: String {
    case precipitationType = "PTY"  // 강수형태 (0:없음 1:비 2:비/눈 3:눈 4:소나기)
    case skyCondition = "SKY"       // 하늘상태 (1:맑음 3:구름많음 4:흐림)
    case temperature = "T1H"        // 기온 (실황)
    case hourlyRain = "RN1"         // 1시간 강수량
    case humidity = "REH"           // 습도
    case windSpeed = "WSD"          // 풍속
}

enum PrecipitationType: Int {
    case none = 0
    case rain = 1
    case rainSnow = 2
    case snow = 3
    case shower = 4

    var isWet: Bool { self != .none }
}

enum SkyCondition: Int {
    case clear = 1
    case cloudy = 3
    case overcast = 4
}

struct WeatherItem: Codable {
    let baseDate: String
    let baseTime: String
    let category: String
    let nx: Int
    let ny: Int
    let obsrValue: String?   // 실황값 (getUltraSrtNcst)
    let fcstDate: String?    // 예보일자
    let fcstTime: String?    // 예보시각
    let fcstValue: String?   // 예보값
}

struct WeatherCondition {
    let precipitation: PrecipitationType
    let sky: SkyCondition
    let temperature: Double
    let rainfallMM: Double   // 1시간 강수량 (mm)
    let humidity: Int        // 습도 (%)
    let isIndoorRecommended: Bool

    init(items: [WeatherItem]) {
        let valueFor: (WeatherCategory) -> String? = { cat in
            items.first(where: { $0.category == cat.rawValue })?.obsrValue
                ?? items.first(where: { $0.category == cat.rawValue })?.fcstValue
        }

        let pty = Int(valueFor(.precipitationType) ?? "0") ?? 0
        precipitation = PrecipitationType(rawValue: pty) ?? .none

        let sky = Int(valueFor(.skyCondition) ?? "1") ?? 1
        self.sky = SkyCondition(rawValue: sky) ?? .clear

        temperature = Double(valueFor(.temperature) ?? "20") ?? 20.0

        let rainRaw = valueFor(.hourlyRain) ?? "0"
        rainfallMM = Double(rainRaw) ?? 0.0

        humidity = Int(valueFor(.humidity) ?? "50") ?? 50

        isIndoorRecommended = precipitation.isWet
    }

    // SF Symbol 이름과 색상
    var weatherIcon: (name: String, colorHex: String) {
        switch precipitation {
        case .rain:     return ("cloud.rain.fill", "#5B8DD9")
        case .rainSnow: return ("cloud.sleet.fill", "#7BA3D4")
        case .snow:     return ("cloud.snow.fill", "#9BB8E0")
        case .shower:   return ("cloud.heavyrain.fill", "#4A7BC8")
        case .none:
            switch sky {
            case .clear:    return ("sun.max.fill", "#F5A623")
            case .cloudy:   return ("cloud.sun.fill", "#8FA8C8")
            case .overcast: return ("cloud.fill", "#6B7B8D")
            }
        }
    }
}

// 기상청 공통 응답 래퍼
struct WeatherResponse: Codable {
    let response: WeatherBody
}

struct WeatherBody: Codable {
    let header: WeatherHeader
    let body: WeatherBodyContent?
}

struct WeatherHeader: Codable {
    let resultCode: String
    let resultMsg: String
}

struct WeatherBodyContent: Codable {
    let items: WeatherItems?
    let numOfRows: Int?
    let pageNo: Int?
    let totalCount: Int?
}

struct WeatherItems: Codable {
    let item: [WeatherItem]
}
