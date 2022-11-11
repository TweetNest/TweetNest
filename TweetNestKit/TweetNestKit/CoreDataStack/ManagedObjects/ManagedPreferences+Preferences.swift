//
//  ManagedPreferences+Preferences.swift
//  TweetNestKit
//
//  Created by 강재홍 on 2022/04/20.
//

import Foundation
import CoreData

extension ManagedPreferences {
    public struct Preferences {
        public var notifyProfileChanges: Bool = true
        public var notifyFollowingChanges: Bool = true
        public var notifyFollowerChanges: Bool = true
        public var notifyBlockingChanges: Bool = false
        public var notifyMutingChanges: Bool = false
    }
}

extension ManagedPreferences.Preferences: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaultPreferences = ManagedPreferences.Preferences()

        self.notifyProfileChanges = try container.decodeIfPresent(Bool.self, forKey: .notifyProfileChanges) ?? defaultPreferences.notifyProfileChanges
        self.notifyFollowingChanges = try container.decodeIfPresent(Bool.self, forKey: .notifyFollowingChanges) ?? defaultPreferences.notifyFollowingChanges
        self.notifyFollowerChanges = try container.decodeIfPresent(Bool.self, forKey: .notifyFollowerChanges) ?? defaultPreferences.notifyFollowerChanges
        self.notifyBlockingChanges = try container.decodeIfPresent(Bool.self, forKey: .notifyBlockingChanges) ?? defaultPreferences.notifyBlockingChanges
        self.notifyMutingChanges = try container.decodeIfPresent(Bool.self, forKey: .notifyMutingChanges) ?? defaultPreferences.notifyMutingChanges
    }
}

@objc
class ManagedPreferencesTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        NSData.self
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value as? ManagedPreferences.Preferences? else {
            preconditionFailure()
        }

        return value.flatMap {
            do {
                return try PropertyListEncoder().encode($0) as NSData
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let value = value as? NSData else {
            return nil
        }

        return try? PropertyListDecoder().decode(ManagedPreferences.Preferences.self, from: value as Data)
    }
}

extension ManagedPreferences.Preferences {
    public init(for context: NSManagedObjectContext) {
        self = context.performAndWait {
            ManagedPreferences.managedPreferences(for: context).preferences
        }
    }

    public init(for context: NSManagedObjectContext) async {
        self = await context.perform {
            ManagedPreferences.managedPreferences(for: context).preferences
        }
    }
}
