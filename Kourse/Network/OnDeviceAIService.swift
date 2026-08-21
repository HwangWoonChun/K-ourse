//
//  OnDeviceAIService.swift
//  Kourse

import Foundation
import FoundationModels

@MainActor
final class OnDeviceAIService {
    static let shared = OnDeviceAIService()
    private init() {}

    func explainCourse(
        spots: [TourSpot],
        theme: TravelTheme,
        duration: TravelDuration,
        isIndoor: Bool
    ) async -> String? {
        let spotList = spots.enumerated()
            .map { "\($0.offset + 1). \($0.element.title)" }
            .joined(separator: "\n")

        let prompt = """
        여행 코스 추천 앱에서 아래 조건으로 코스를 생성했어. 각 장소가 왜 선택됐는지, 코스 흐름이 왜 이런지 한국어로 3~4문장으로 간결하게 설명해줘. 전문가처럼 설명하되 친근한 말투로.

        테마: \(theme.rawValue)
        일정: \(duration.rawValue)
        환경: \(isIndoor ? "실내 위주" : "실외 위주")
        선택된 장소:
        \(spotList)
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            return nil
        }
    }
}
