//
//  WeatherViewModel.swift
//  Kourse
//

import Foundation
import CoreLocation
import Combine
import UIKit

// MARK: - LocationDelegate (NSObject 분리)

private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onAuthorizationChange: (() -> Void)?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }
        onAuthorizationChange?()
    }
}

// MARK: - WeatherViewModel

final class WeatherViewModel: ObservableObject {
    @Published var condition: WeatherCondition?
    @Published var locationName: String = "위치 확인 중…"
    @Published var isLoading = false
    @Published var isLocationAuthorized: Bool = false
    @Published var latitude: Double = 37.5665   // 기본값: 서울
    @Published var longitude: Double = 126.9780

    private let locationManager = CLLocationManager()
    private let locationDelegate = LocationDelegate()
    private let geocoder = CLGeocoder()
    private var cancellables = Set<AnyCancellable>()
    private var lastFetchDate: Date? = nil
    private let refreshInterval: TimeInterval = 600 // 10분

    private var shouldRefresh: Bool {
        guard let last = lastFetchDate else { return true }
        return Date().timeIntervalSince(last) >= refreshInterval
    }

    init() {
        locationManager.delegate = locationDelegate
        // 권한 상태가 바뀌면 즉시 갱신
        locationDelegate.onAuthorizationChange = { [weak self] in
            self?.requestLocationAndLoad(force: true)
        }
    }

    // force: true면 10분 쿨다운 무시
    func requestLocationAndLoad(force: Bool = false) {
        guard force || shouldRefresh else { return }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationName = "위치 확인 중…"
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isLocationAuthorized = true
            locationName = "위치 확인 중…"
            Task { await fetchLocationAndWeather() }
        case .denied, .restricted:
            isLocationAuthorized = false
            locationName = "위치 권한이 없어요"
            condition = nil
        @unknown default:
            break
        }
    }

    private func fetchLocationAndWeather() async {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                guard let location = update.location else { continue }
                latitude = location.coordinate.latitude
                longitude = location.coordinate.longitude
                reverseGeocode(location)
                await fetchWeather(latitude: location.coordinate.latitude,
                                   longitude: location.coordinate.longitude)
                break
            }
        } catch {
            locationName = "위치를 알 수 없어요"
            condition = nil
        }
    }

    private func fetchWeather(latitude: Double, longitude: Double) async {
        isLoading = true
        do {
            condition = try await WeatherAPIService.shared.fetchCurrentWeather(
                latitude: latitude, longitude: longitude
            )
            lastFetchDate = Date()
        } catch {
            do {
                condition = try await WeatherAPIService.shared.fetchShortForecast(
                    latitude: latitude, longitude: longitude
                )
                lastFetchDate = Date()
            } catch {
                condition = nil
            }
        }
        isLoading = false
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let p = placemarks?.first else { return }
            let name = [p.locality, p.subLocality].compactMap { $0 }.joined(separator: " ")
            DispatchQueue.main.async {
                self.locationName = name.isEmpty ? "현재 위치" : name
            }
        }
    }
}
