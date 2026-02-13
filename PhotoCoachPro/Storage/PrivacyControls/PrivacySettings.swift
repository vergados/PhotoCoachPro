//
//  PrivacySettings.swift
//  PhotoCoachPro
//
//  User privacy preferences
//

import Foundation

/// User privacy preferences (stored in UserDefaults)
@MainActor
class PrivacySettings: ObservableObject {
    static let shared = PrivacySettings()

    @Published var stripMetadataOnExport: Bool {
        didSet { UserDefaults.standard.set(stripMetadataOnExport, forKey: Keys.stripMetadata) }
    }

    @Published var stripLocationOnExport: Bool {
        didSet { UserDefaults.standard.set(stripLocationOnExport, forKey: Keys.stripLocation) }
    }

    @Published var saveCritiqueHistory: Bool {
        didSet { UserDefaults.standard.set(saveCritiqueHistory, forKey: Keys.saveCritiques) }
    }

    @Published var allowNetworkAccess: Bool {
        didSet { UserDefaults.standard.set(allowNetworkAccess, forKey: Keys.allowNetwork) }
    }

    private enum Keys {
        static let stripMetadata = "privacy.stripMetadata"
        static let stripLocation = "privacy.stripLocation"
        static let saveCritiques = "privacy.saveCritiques"
        static let allowNetwork = "privacy.allowNetwork"
    }

    private init() {
        self.stripMetadataOnExport = UserDefaults.standard.bool(forKey: Keys.stripMetadata)
        self.stripLocationOnExport = UserDefaults.standard.bool(forKey: Keys.stripLocation)
        self.saveCritiqueHistory = UserDefaults.standard.bool(forKey: Keys.saveCritiques)
        self.allowNetworkAccess = UserDefaults.standard.bool(forKey: Keys.allowNetwork)
    }

    // MARK: - Quick Actions

    func resetToDefaults() {
        stripMetadataOnExport = false
        stripLocationOnExport = false
        saveCritiqueHistory = true
        allowNetworkAccess = false
    }

    func maximumPrivacy() {
        stripMetadataOnExport = true
        stripLocationOnExport = true
        saveCritiqueHistory = false
        allowNetworkAccess = false
    }
}
