//
//  TourSpotDetail.swift
//  Kourse
//

import Foundation

// detailCommon2 응답
struct TourSpotCommon: Codable {
    let contentId: String
    let contentTypeId: String
    let title: String
    let address: String
    let tel: String?
    let homepage: String?
    let overview: String?
    let thumbnail: String?
    let mapX: Double
    let mapY: Double

    enum CodingKeys: String, CodingKey {
        case contentId = "contentid"
        case contentTypeId = "contenttypeid"
        case title
        case address = "addr1"
        case tel
        case homepage
        case overview
        case thumbnail = "firstimage"
        case mapX = "mapx"
        case mapY = "mapy"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contentId = try c.decode(String.self, forKey: .contentId)
        contentTypeId = try c.decode(String.self, forKey: .contentTypeId)
        title = try c.decode(String.self, forKey: .title)
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        tel = try c.decodeIfPresent(String.self, forKey: .tel)
        homepage = try c.decodeIfPresent(String.self, forKey: .homepage)
        overview = try c.decodeIfPresent(String.self, forKey: .overview)
        thumbnail = try c.decodeIfPresent(String.self, forKey: .thumbnail)
        let xStr = try c.decodeIfPresent(String.self, forKey: .mapX) ?? "0"
        let yStr = try c.decodeIfPresent(String.self, forKey: .mapY) ?? "0"
        mapX = Double(xStr) ?? 0
        mapY = Double(yStr) ?? 0
    }
}

// detailIntro2 응답 — contentTypeId별로 필드가 다름, 공통 필드만 추출
struct TourSpotIntro: Codable {
    let contentId: String
    let openTime: String?      // 관광지: usetime / 음식점: opentimefood
    let restDate: String?      // 관광지: restdate / 음식점: restdatefood
    let parking: String?       // parkingfood / parking
    let reservationUrl: String?

    enum CodingKeys: String, CodingKey {
        case contentId = "contentid"
        case openTime = "usetime"
        case restDate = "restdate"
        case parking
        case reservationUrl = "reservationurl"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contentId = try c.decode(String.self, forKey: .contentId)
        openTime = try c.decodeIfPresent(String.self, forKey: .openTime)
        restDate = try c.decodeIfPresent(String.self, forKey: .restDate)
        parking = try c.decodeIfPresent(String.self, forKey: .parking)
        reservationUrl = try c.decodeIfPresent(String.self, forKey: .reservationUrl)
    }
}

// detailImage2 응답
struct TourSpotImage: Codable, Identifiable {
    var id: String { originimgurl }
    let originimgurl: String
    let smallimageurl: String?
    let imgname: String?
    let cpyrhtDivCd: String? // 저작권 유형
}
