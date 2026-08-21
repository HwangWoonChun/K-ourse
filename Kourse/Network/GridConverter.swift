//
//  GridConverter.swift
//  Kourse
//
//  기상청 격자 좌표(nx, ny) ↔ 위경도(WGS84) 변환
//  기상청 공식 변환 공식 기반
//

import Foundation

struct GridCoordinate {
    let nx: Int
    let ny: Int
}

enum GridConverter {
    private static let RE = 6371.00877      // 지구 반경 (km)
    private static let GRID = 5.0           // 격자 간격 (km)
    private static let SLAT1 = 30.0        // 투영 위도 1 (degree)
    private static let SLAT2 = 60.0        // 투영 위도 2 (degree)
    private static let OLON = 126.0        // 기준점 경도 (degree)
    private static let OLAT = 38.0         // 기준점 위도 (degree)
    private static let XO = 43.0           // 기준점 X 좌표 (격자)
    private static let YO = 136.0          // 기준점 Y 좌표 (격자)

    static func convert(latitude: Double, longitude: Double) -> GridCoordinate {
        let DEGRAD = Double.pi / 180.0

        let re = RE / GRID
        let slat1 = SLAT1 * DEGRAD
        let slat2 = SLAT2 * DEGRAD
        let olon = OLON * DEGRAD
        let olat = OLAT * DEGRAD

        var sn = tan(Double.pi * 0.25 + slat2 * 0.5) / tan(Double.pi * 0.25 + slat1 * 0.5)
        sn = log(cos(slat1) / cos(slat2)) / log(sn)
        var sf = tan(Double.pi * 0.25 + slat1 * 0.5)
        sf = pow(sf, sn) * cos(slat1) / sn
        var ro = tan(Double.pi * 0.25 + olat * 0.5)
        ro = re * sf / pow(ro, sn)

        let lat = latitude * DEGRAD
        let lon = longitude * DEGRAD

        var ra = tan(Double.pi * 0.25 + lat * 0.5)
        ra = re * sf / pow(ra, sn)
        var theta = lon - olon
        if theta > Double.pi { theta -= 2.0 * Double.pi }
        if theta < -Double.pi { theta += 2.0 * Double.pi }
        theta *= sn

        let x = Int(ra * sin(theta) + XO + 0.5)
        let y = Int(ro - ra * cos(theta) + YO + 0.5)

        return GridCoordinate(nx: x, ny: y)
    }
}
