//
//  Session+UpdatesAll.swift
//  TweetNestKit
//
//  Created by Jaehong Kang on 2022/05/20.
//

import Foundation
import CoreData

extension Session {
    @discardableResult
    public func updateAllAccounts() async throws -> [(NSManagedObjectID, Result<Bool, Swift.Error>)] {
        let context = persistentContainer.newBackgroundContext()
        context.undoManager = nil

        let accountObjectIDs: [NSManagedObjectID] = try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: ManagedAccount.entity().name!)
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \ManagedAccount.preferringSortOrder, ascending: true),
                NSSortDescriptor(keyPath: \ManagedAccount.creationDate, ascending: false),
            ]
            fetchRequest.resultType = .managedObjectIDResultType

            return try context.fetch(fetchRequest)
        }

        return await withTaskGroup(of: (NSManagedObjectID, Result<Bool, Swift.Error>).self) { taskGroup in
            accountObjectIDs.forEach { accountObjectID in
                taskGroup.addTask {
                    do {
                        let updateResults = try await self.updateAccount(accountObjectID, context: context)
                        return (accountObjectID, .success(updateResults?.oldUserDetailObjectID != updateResults?.newUserDetailObjectID))
                    } catch {
                        return (accountObjectID, .failure(error))
                    }
                }
            }

            return await taskGroup.reduce(into: [], { $0.append($1) })
        }
    }
}
