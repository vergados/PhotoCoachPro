//
//  CloudKitService.swift
//  PhotoCoachPro
//
//  CloudKit service wrapper
//

import Foundation
import CloudKit

/// CloudKit service for record operations
actor CloudKitService {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let deviceID: String

    init(containerIdentifier: String = "iCloud.com.photocoachpro") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        #if os(iOS)
        self.deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        // macOS: use a persistent device identifier
        self.deviceID = Self.getOrCreateMacDeviceID()
        #endif
    }

    #if os(macOS)
    private static func getOrCreateMacDeviceID() -> String {
        let defaults = UserDefaults.standard
        let key = "com.photocoachpro.deviceID"

        if let existing = defaults.string(forKey: key) {
            return existing
        }

        let newID = UUID().uuidString
        defaults.set(newID, forKey: key)
        return newID
    }
    #endif

    // MARK: - Account Status

    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    func isAccountAvailable() async -> Bool {
        do {
            let status = try await checkAccountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    // MARK: - Save Operations

    func save<T: CloudRecordConvertible>(_ item: T) async throws -> T {
        let record = try item.toCKRecord()

        let savedRecord = try await privateDatabase.save(record)

        return try T.from(savedRecord)
    }

    func saveBatch<T: CloudRecordConvertible>(_ items: [T]) async throws -> [T] {
        let records = try items.map { try $0.toCKRecord() }

        let (savedRecords, _) = try await privateDatabase.modifyRecords(saving: records, deleting: [])

        return try savedRecords.compactMap { recordResult in
            switch recordResult {
            case .success(let record):
                return try T.from(record)
            case .failure:
                return nil
            }
        }
    }

    // MARK: - Fetch Operations

    func fetch<T: CloudRecordConvertible>(recordID: CKRecord.ID, type: T.Type) async throws -> T {
        let record = try await privateDatabase.record(for: recordID)
        return try T.from(record)
    }

    func fetchAll<T: CloudRecordConvertible>(recordType: String, type: T.Type) async throws -> [T] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]

        let (results, _) = try await privateDatabase.records(matching: query)

        return try results.compactMap { recordResult in
            switch recordResult.1 {
            case .success(let record):
                return try T.from(record)
            case .failure:
                return nil
            }
        }
    }

    func fetchModified<T: CloudRecordConvertible>(
        recordType: String,
        since date: Date,
        type: T.Type
    ) async throws -> [T] {
        let predicate = NSPredicate(format: "modificationDate > %@", date as NSDate)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]

        let (results, _) = try await privateDatabase.records(matching: query)

        return try results.compactMap { recordResult in
            switch recordResult.1 {
            case .success(let record):
                return try T.from(record)
            case .failure:
                return nil
            }
        }
    }

    // MARK: - Delete Operations

    func delete(recordID: CKRecord.ID) async throws {
        _ = try await privateDatabase.deleteRecord(withID: recordID)
    }

    func deleteBatch(recordIDs: [CKRecord.ID]) async throws {
        let (_, _) = try await privateDatabase.modifyRecords(saving: [], deleting: recordIDs)
    }

    // MARK: - Query Operations

    func query<T: CloudRecordConvertible>(
        recordType: String,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor] = [],
        type: T.Type
    ) async throws -> [T] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors.isEmpty ? [NSSortDescriptor(key: "modificationDate", ascending: false)] : sortDescriptors

        let (results, _) = try await privateDatabase.records(matching: query)

        return try results.compactMap { recordResult in
            switch recordResult.1 {
            case .success(let record):
                return try T.from(record)
            case .failure:
                return nil
            }
        }
    }

    // MARK: - Subscriptions

    func createSubscription(recordType: String, subscriptionID: String) async throws {
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        _ = try await privateDatabase.save(subscription)
    }

    func deleteSubscription(subscriptionID: String) async throws {
        _ = try await privateDatabase.deleteSubscription(withID: subscriptionID)
    }

    func fetchAllSubscriptions() async throws -> [CKSubscription] {
        try await privateDatabase.allSubscriptions()
    }

    // MARK: - Change Tracking

    func fetchChanges(
        recordType: String,
        serverChangeToken: CKServerChangeToken? = nil
    ) async throws -> (changed: [CKRecord], deleted: [CKRecord.ID], serverChangeToken: CKServerChangeToken?) {
        // Use CKFetchRecordZoneChangesOperation for efficient delta sync
        // Simplified implementation - would need full zone tracking in production

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        // For simplicity, fetch all records modified since token
        if let token = serverChangeToken {
            // In production, use CKFetchRecordZoneChangesOperation
            // For now, fetch all and filter
            let all = try await fetchAll(recordType: recordType, type: CKRecord.self as! CloudRecordConvertible.Type) as! [CKRecord]
            changedRecords = all
        } else {
            // Initial fetch
            let all = try await fetchAll(recordType: recordType, type: CKRecord.self as! CloudRecordConvertible.Type) as! [CKRecord]
            changedRecords = all
        }

        return (changedRecords, deletedRecordIDs, nil)
    }

    // MARK: - Conflict Resolution

    func resolveConflict(
        localRecord: CKRecord,
        serverRecord: CKRecord,
        resolution: SyncConflict.Resolution
    ) async throws -> CKRecord {
        switch resolution {
        case .keepLocal:
            // Force save local record
            return try await privateDatabase.save(localRecord)

        case .keepRemote:
            // Use server record
            return serverRecord

        case .keepBoth:
            // Create new record for local version
            var duplicateRecord = localRecord
            duplicateRecord.recordID = CKRecord.ID(recordName: "\(localRecord.recordID.recordName)-duplicate")
            _ = try await privateDatabase.save(duplicateRecord)
            return serverRecord

        case .manual:
            // Return server record, let caller handle
            return serverRecord
        }
    }

    // MARK: - Helper Methods

    var currentDeviceID: String {
        deviceID
    }

    func isNetworkAvailable() -> Bool {
        // Simplified - in production, use NWPathMonitor
        return true
    }
}
