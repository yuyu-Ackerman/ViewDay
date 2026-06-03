import CoreData
import Foundation

/// 日记标签仓储。
/// 标签本身可复用，日记与标签通过关系实体连接。
final class TagRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    @discardableResult
    func saveTag(name: String, colorHex: String? = nil) throws -> Tag {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw RepositoryError.invalidStoredObject(entityName: "TagEntity")
        }

        if let existing = try fetchTag(named: trimmedName) {
            // 标签名称大小写不敏感复用，避免输入页重复创建视觉上相同的标签。
            return existing
        }

        let now = Date()
        let object = NSEntityDescription.insertNewObject(forEntityName: "TagEntity", into: context)
        object.setValue(UUID(), forKey: "localId")
        object.setValue(trimmedName, forKey: "name")
        object.setValue(colorHex, forKey: "colorHex")
        CoreDataValueMapper.applySyncFields(
            to: object,
            remoteId: nil,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            syncStatus: .pendingCreate
        )

        try context.save()
        return try mapTag(object)
    }

    func fetchAllTags() throws -> [Tag] {
        let request = baseTagFetchRequest()
        request.predicate = NSPredicate(format: "deletedAt == nil")
        request.sortDescriptors = [
            NSSortDescriptor(key: "updatedAt", ascending: false),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        return try context.fetch(request).map(mapTag)
    }

    func fetchTags(forDiaryId diaryId: UUID) throws -> [Tag] {
        let relationRequest = NSFetchRequest<NSManagedObject>(entityName: "DiaryTagRelationEntity")
        relationRequest.predicate = NSPredicate(format: "diaryId == %@", diaryId as CVarArg)
        let tagIds = try context.fetch(relationRequest).compactMap { $0.value(forKey: "tagId") as? UUID }

        guard !tagIds.isEmpty else { return [] }

        let tagRequest = baseTagFetchRequest()
        tagRequest.predicate = NSPredicate(format: "deletedAt == nil AND localId IN %@", tagIds)
        tagRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return try context.fetch(tagRequest).map(mapTag)
    }

    func replaceTags(forDiaryId diaryId: UUID, with tags: [Tag]) throws {
        let relationRequest = NSFetchRequest<NSManagedObject>(entityName: "DiaryTagRelationEntity")
        relationRequest.predicate = NSPredicate(format: "diaryId == %@", diaryId as CVarArg)
        // 替换关系比逐项 diff 更直接，适合当前标签数量少且编辑入口集中的场景。
        try context.fetch(relationRequest).forEach(context.delete)

        for tag in tags {
            let relation = NSEntityDescription.insertNewObject(forEntityName: "DiaryTagRelationEntity", into: context)
            relation.setValue(diaryId, forKey: "diaryId")
            relation.setValue(tag.localId, forKey: "tagId")
        }

        try context.save()
    }

    private func fetchTag(named name: String) throws -> Tag? {
        let request = baseTagFetchRequest()
        request.predicate = NSPredicate(format: "deletedAt == nil AND name =[cd] %@", name)
        request.fetchLimit = 1
        return try context.fetch(request).first.map(mapTag)
    }

    private func baseTagFetchRequest() -> NSFetchRequest<NSManagedObject> {
        NSFetchRequest<NSManagedObject>(entityName: "TagEntity")
    }

    private func mapTag(_ object: NSManagedObject) throws -> Tag {
        // 必填字段缺失说明 Core Data 模型或迁移有问题，向上抛出仓储错误便于测试定位。
        guard
            let localId = object.value(forKey: "localId") as? UUID,
            let name = object.value(forKey: "name") as? String,
            let createdAt = object.value(forKey: "createdAt") as? Date,
            let updatedAt = object.value(forKey: "updatedAt") as? Date
        else {
            throw RepositoryError.invalidStoredObject(entityName: "TagEntity")
        }

        let syncStatusRawValue = object.value(forKey: "syncStatus") as? String
        return Tag(
            localId: localId,
            remoteId: object.value(forKey: "remoteId") as? String,
            name: name,
            colorHex: object.value(forKey: "colorHex") as? String,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: object.value(forKey: "deletedAt") as? Date,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}
