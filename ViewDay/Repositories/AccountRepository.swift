import CoreData
import Foundation

/// 账户仓储。
/// 当前账本先使用默认账户，为未来多账户扩展保留数据入口。
final class AccountRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    /// 获取默认账户。
    /// 当前账本保存流水时没有显式账户选择，因此默认账户是账本数据的基础上下文。
    func fetchDefaultAccount() throws -> Account? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "AccountEntity")
        request.predicate = NSPredicate(format: "deletedAt == nil AND isDefault == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        request.fetchLimit = 1
        return try context.fetch(request).first.map(mapAccount)
    }

    private func mapAccount(_ object: NSManagedObject) throws -> Account {
        // 必填字段缺失说明 Core Data 模型或迁移有问题，向上抛出仓储错误便于测试定位。
        guard
            let localId = object.value(forKey: "localId") as? UUID,
            let name = object.value(forKey: "name") as? String,
            let createdAt = object.value(forKey: "createdAt") as? Date,
            let updatedAt = object.value(forKey: "updatedAt") as? Date
        else {
            throw RepositoryError.invalidStoredObject(entityName: "AccountEntity")
        }

        let syncStatusRawValue = object.value(forKey: "syncStatus") as? String
        return Account(
            localId: localId,
            remoteId: object.value(forKey: "remoteId") as? String,
            name: name,
            isDefault: object.value(forKey: "isDefault") as? Bool ?? false,
            sortOrder: CoreDataValueMapper.int(object, key: "sortOrder") ?? 0,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: object.value(forKey: "deletedAt") as? Date,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}
