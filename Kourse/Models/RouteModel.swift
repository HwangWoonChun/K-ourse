//
//  RouteModel.swift
//  Kourse
//

import Foundation
import CoreLocation  // RouteResult.path에 CLLocationCoordinate2D 사용

// 경로 탐색 결과
struct RouteResult {
    let distance: Int                           // 거리 (m)
    let duration: Int                           // 소요시간 (초)
    let summary: String                         // "도보 5분" / "차량 12분"
    var path: [CLLocationCoordinate2D] = []    // 도로 경유 좌표 (없으면 직선)

    var durationMinutes: Int { duration / 60 }

    var formattedDuration: String {
        durationMinutes < 60
            ? "\(durationMinutes)분"
            : "\(durationMinutes / 60)시간 \(durationMinutes % 60)분"
    }

    var formattedDistance: String {
        distance < 1000
            ? "\(distance)m"
            : String(format: "%.1fkm", Double(distance) / 1000)
    }
}

// 카카오 로컬 좌표→행정구역 응답
struct GeocodingRegionResponse: Codable {
    let documents: [GeocodingRegionDocument]
}

struct GeocodingRegionDocument: Codable {
    let regionType: String
    let addressName: String
    let region1DepthName: String  // 시도
    let region2DepthName: String  // 시군구
    let region3DepthName: String  // 읍면동

    enum CodingKeys: String, CodingKey {
        case regionType = "region_type"
        case addressName = "address_name"
        case region1DepthName = "region_1depth_name"
        case region2DepthName = "region_2depth_name"
        case region3DepthName = "region_3depth_name"
    }
}
