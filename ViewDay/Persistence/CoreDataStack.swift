import CoreData
import Foundation

/// Core Data 基础设施入口。
/// 默认使用应用持久化存储，测试可通过 `inMemory` 创建隔离的内存存储。
final class CoreDataStack {
    static let shared = CoreDataStack()

    let persistentContainer: NSPersistentContainer

    /// 主线程上下文，供 UIKit 页面和仓储默认使用。
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    init(inMemory: Bool = false) {
        persistentContainer = NSPersistentContainer(name: "ViewDay")

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            persistentContainer.persistentStoreDescriptions = [description]
        }

        persistentContainer.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }

        // 本地编辑优先覆盖同属性冲突，符合当前本地优先的数据策略。
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext.automaticallyMergesChangesFromParent = true
    }

    /// 保存主上下文中的待提交更改。
    func saveContext() {
        guard viewContext.hasChanges else { return }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved Core Data save error \(nsError), \(nsError.userInfo)")
        }
    }
}
