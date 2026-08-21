//
//  MockData.swift
//  Kourse
//

import Foundation

enum MockData {
    static let spots: [TourSpot] = [
        mockSpot(
            id: "126508",
            typeId: ContentType.tourist.rawValue,
            title: "경복궁",
            address: "서울특별시 종로구 사직로 161",
            x: 126.9770, y: 37.5796,
            thumbnail: nil,
            distance: 320
        ),
        mockSpot(
            id: "126273",
            typeId: ContentType.culture.rawValue,
            title: "국립고궁박물관",
            address: "서울특별시 종로구 효자로 12",
            x: 126.9745, y: 37.5785,
            thumbnail: nil,
            distance: 450
        ),
        mockSpot(
            id: "715369",
            typeId: ContentType.restaurant.rawValue,
            title: "통인시장 기름떡볶이",
            address: "서울특별시 종로구 자하문로15길 18",
            x: 126.9706, y: 37.5795,
            thumbnail: nil,
            distance: 680
        ),
        mockSpot(
            id: "1876753",
            typeId: ContentType.shopping.rawValue,
            title: "인사동 쌈지길",
            address: "서울특별시 종로구 인사동길 44",
            x: 126.9852, y: 37.5743,
            thumbnail: nil,
            distance: 1100
        ),
        mockSpot(
            id: "264570",
            typeId: ContentType.culture.rawValue,
            title: "낙원악기상가",
            address: "서울특별시 종로구 삼일대로 428",
            x: 126.9872, y: 37.5748,
            thumbnail: nil,
            distance: 1250
        )
    ]

    // 날씨별 시나리오
    static var indoorSpots: [TourSpot] {
        spots.filter { $0.contentType?.isIndoor == true }
    }

    static var outdoorSpots: [TourSpot] {
        spots.filter { $0.contentType?.isIndoor == false }
    }

    private static func mockSpot(
        id: String,
        typeId: String,
        title: String,
        address: String,
        x: Double,
        y: Double,
        thumbnail: String?,
        distance: Double
    ) -> TourSpot {
        let json: [String: Any] = [
            "contentid": id,
            "contenttypeid": typeId,
            "title": title,
            "addr1": address,
            "mapx": String(x),
            "mapy": String(y),
            "firstimage": thumbnail as Any,
            "distance": String(distance)
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(TourSpot.self, from: data)
    }
}
