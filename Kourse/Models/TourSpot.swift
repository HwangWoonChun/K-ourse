//
//  TourSpot.swift
//  Kourse
//

import Foundation

// TourAPI contentTypeId 분류
enum ContentType: String, Codable {
    case tourist = "12"       // 관광지 (실외)
    case culture = "14"       // 문화시설 (실내)
    case festival = "15"      // 행사/공연/축제
    case leisure = "28"       // 레포츠 (실외)
    case accommodation = "32" // 숙박
    case shopping = "38"      // 쇼핑 (실내)
    case restaurant = "39"    // 음식점 (실내)

    var isIndoor: Bool {
        switch self {
        case .culture, .shopping, .restaurant, .accommodation: true
        case .tourist, .festival, .leisure: false
        }
    }
}

struct TourSpot: Identifiable, Codable {
    let id: String          // contentid
    let contentTypeId: String
    let title: String
    let address: String
    let mapX: Double        // 경도
    let mapY: Double        // 위도
    let thumbnail: String?  // firstimage
    let tel: String?
    let distance: Double?   // locationBasedList 응답 시 포함

    var contentType: ContentType? {
        ContentType(rawValue: contentTypeId)
    }

    enum CodingKeys: String, CodingKey {
        case id = "contentid"
        case contentTypeId = "contenttypeid"
        case title
        case address = "addr1"
        case mapX = "mapx"
        case mapY = "mapy"
        case thumbnail = "firstimage"
        case tel
        case distance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        contentTypeId = try c.decode(String.self, forKey: .contentTypeId)
        title = try c.decode(String.self, forKey: .title)
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        tel = try c.decodeIfPresent(String.self, forKey: .tel)
        thumbnail = try c.decodeIfPresent(String.self, forKey: .thumbnail)

        // TourAPI는 좌표·거리를 String으로 내려줌
        let xStr = try c.decodeIfPresent(String.self, forKey: .mapX) ?? "0"
        let yStr = try c.decodeIfPresent(String.self, forKey: .mapY) ?? "0"
        mapX = Double(xStr) ?? 0
        mapY = Double(yStr) ?? 0

        let distStr = try c.decodeIfPresent(String.self, forKey: .distance)
        distance = distStr.flatMap(Double.init)
    }
}
