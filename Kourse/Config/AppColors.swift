//
//  AppColors.swift
//  Kourse
//

import SwiftUI

extension Color {
    static let kBackground    = Color(red: 0.957, green: 0.949, blue: 0.933)
    static let kGreen         = Color(red: 0.169, green: 0.286, blue: 0.169)
    static let kGreenLight    = Color(red: 0.169, green: 0.286, blue: 0.169).opacity(0.08)
    static let kTextPrimary   = Color(red: 0.13, green: 0.13, blue: 0.13)
    static let kTextSecondary = Color(red: 0.45, green: 0.45, blue: 0.45)
    static let kTabBarIcon    = Color(red: 0.6, green: 0.6, blue: 0.6)

    init?(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let val = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8)  & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}
