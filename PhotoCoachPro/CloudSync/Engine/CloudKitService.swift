//
//  CloudKitService.swift
//  PhotoCoachPro
//
//  CloudKit service wrapper
//

import Foundation
import CloudKit
import Network

/// CloudKit service for record operations
actor CloudKitService {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let deviceID: String
    private let _networkMonitor: NWPathMonitor
    private nonisolated(unsafe) var _networkAvailable: Bool = true

    init(containerIdentifier: String = "iCloud.com.photocoachpro") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        #if os(iOS)
        self.deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        // macOS: use a persistent device identifier
        self.deviceID = Self.getOrCreateMacDeviceID()
        #endif
        self._networkMonitor = NWPathMonitor()
        self._networkMonitor.pathUpdateHandler = { [self] path in
            self._networkAvailable = path.status == .satisfied
        }
        self._networkMonitor.start(queue: DispatchQueue(label: "com.photocoachpro.network", qos: .utility))
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

        return try savedRecords.compactMap { (_, result) in
            switch result {
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

    @discardableResult
    func deleteBatch(recordIDs: [CKRecord.ID]) async throws -> [CKRecord.ID] {
        do {
            let (_, deleteResults) = try await privateDatabase.modifyRecords(saving: [], deleting: recordIDs)
            var deleted: [CKRecord.ID] = []
            for (recordID, result) in deleteResults {
                switch result {
                case .success:
                    deleted.append(recordID)
                case .failure(let error):
                    // Log partial failure — caller still receives the successfully deleted IDs
                    print("[CloudKitService] deleteBatch partial failure for \(recordID.recordName): \(error.localizedDescription)")
                }
            }
            return deleted
        } catch let ckError as CKError where ckError.code == .partialFailure {
            // Extract which IDs succeeded from the partial failure userInfo
            let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] ?? [:]
            let failed = Set(partialErrors.keys)
            let succeeded = recordIDs.filter { !failed.contains($0) }
            print("[CloudKitService] deleteBatch partial failure: \(partialErrors.count) of \(recordIDs.count) failed")
            return succeeded
        }
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
        let zoneID = CKRecordZone.default().zoneID

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        var newServerToken: CKServerChangeToken?

        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        config.previousServerChangeToken = serverChangeToken

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: config]
        )

        // Accumulate changed records (filtered by recordType)
        operation.recordWasChangedBlock = { _, result in
            if case .success(let record) = result, record.recordType == recordType {
                changedRecords.append(record)
            }
        }

        // Accumulate deleted record IDs
        operation.recordWithIDWasDeletedBlock = { recordID, recordType_ in
            if recordType_ == recordType {
                deletedRecordIDs.append(recordID)
            }
        }

        // Capture new change token per zone
        operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            newServerToken = token
        }

        // Final token after fetch completes
        operation.recordZoneFetchResultBlock = { _, result in
            if case .success(let (token, _, _)) = result {
                newServerToken = token
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDatabase.add(operation)
        }

        return (changedRecords, deletedRecordIDs, newServerToken)
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
            // Create a duplicate of the local record with a new ID so both versions survive
            let newRecordID = CKRecord.ID(
                recordName: UUID().uuidString,
                zoneID: localRecord.recordID.zoneID
            )
            let duplicate = CKRecord(recordType: localRecord.recordType, recordID: newRecordID)
            for key in localRecord.allKeys() {
                duplicate[key] = localRecord[key]
            }
            // Save the duplicate; the server record already exists
            _ = try await privateDatabase.save(duplicate)
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
        _networkAvailable
    }
}
