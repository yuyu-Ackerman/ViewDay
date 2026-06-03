import CoreData
import Foundation

/// 应用启动时的默认数据补齐器。
/// 目前只确保账本存在一个默认账户，避免新增流水时缺少账户上下文。
final class DefaultDataSeeder {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func seedIfNeeded() throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "AccountEntity")
        request.predicate = NSPredicate(format: "deletedAt == nil AND isDefault == YES")
        request.fetchLimit = 1

        if try context.count(for: request) > 0 {
            return
        }

        // 默认账户属于本地基础数据，不需要进入待同步创建队列。
        let now = Date()
        let account = NSEntityDescription.insertNewObject(forEntityName: "AccountEntity", into: context)
        account.setValue(UUID(), forKey: "localId")
        account.setValue("默认账户", forKey: "name")
        account.setValue(true, forKey: "isDefault")
        account.setValue(0, forKey: "sortOrder")
        CoreDataValueMapper.applySyncFields(
            to: account,
            remoteId: nil,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            syncStatus: .localOnly
        )

        try context.save()
    }
}
