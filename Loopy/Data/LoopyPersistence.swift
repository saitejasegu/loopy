import Foundation
import SwiftData

enum LoopyPersistence {
    static let appGroupID = "group.com.saitejasegu.loopy"
    static let cloudKitContainerID = "iCloud.com.saitejasegu.loopy"

    @MainActor
    static func makeContainer(cloudKitEnabled: Bool = true) -> ModelContainer {
        let schema = Schema([Habit.self, HabitCheckIn.self])
        let url = storeURL()

        if cloudKitEnabled {
            do {
                let configuration = ModelConfiguration(
                    "Loopy",
                    schema: schema,
                    url: url,
                    cloudKitDatabase: .private(cloudKitContainerID)
                )
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                // Fall back to local-only if CloudKit is unavailable (simulator, signed-out iCloud).
            }
        }

        do {
            let local = ModelConfiguration(
                "Loopy",
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [local])
        } catch {
            fatalError("Failed to create Loopy ModelContainer: \(error)")
        }
    }

    static func storeURL() -> URL {
        let fileName = "Loopy.store"
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return groupURL.appendingPathComponent(fileName)
        }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent(fileName)
    }

    static var isICloudAccountAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
