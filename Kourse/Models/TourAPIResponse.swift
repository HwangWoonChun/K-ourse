//
//  TourAPIResponse.swift
//  Kourse
//

import Foundation

// TourAPI 공통 응답 래퍼
struct TourAPIResponse<T: Codable>: Codable {
    let response: TourAPIBody<T>
}

struct TourAPIBody<T: Codable>: Codable {
    let header: TourAPIHeader
    let body: TourAPIBodyContent<T>
}

struct TourAPIHeader: Codable {
    let resultCode: String
    let resultMsg: String
}

struct TourAPIBodyContent<T: Codable>: Codable {
    let items: TourAPIItems<T>?
    let numOfRows: Int
    let pageNo: Int
    let totalCount: Int
}

struct TourAPIItems<T: Codable>: Codable {
    let item: [T]
}
