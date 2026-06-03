import CoreData
import Foundation

/// 附件仓储。
/// 管理附件元数据，并在软删除时委托存储服务清理本地文件。
final class AttachmentRepository {
    private let context: NSManagedObjectContext
    private let storageService: AttachmentStorageService

    init(
        context: NSManagedObjectContext = CoreDataStack.shared.viewContext,
        storageService: AttachmentStorageService = AttachmentStorageService()
    ) {
        self.context = context
        self.storageService = storageService
    }

    /// 保存或更新附件元数据。
    ///
    /// - Parameter attachment: 已经写入本地文件系统的附件信息。
    /// - Returns: 从 Core Data 重新映射后的附件模型。
    @discardableResult
    func save(_ attachment: Attachment) throws -> Attachment {
        // localId 是附件的本地稳定身份，支持后续补写远端 URL 或同步状态。
        let object = try existingObject(id: attachment.localId) ?? NSEntityDescription.insertNewObject(forEntityName: "AttachmentEntity", into: context)

        object.setValue(attachment.localId, forKey: "localId")
        object.setValue(attachment.ownerId, forKey: "ownerId")
        object.setValue(attachment.ownerType.rawValue, forKey: "ownerType")
        object.setValue(attachment.type.rawValue, forKey: "type")
        object.setValue(attachment.localFilePath, forKey: "localFilePath")
        object.setValue(attachment.remoteURL, forKey: "remoteURL")
        object.setValue(attachment.fileName, forKey: "fileName")
        object.setValue(attachment.mimeType, forKey: "mimeType")
        object.setValue(attachment.fileSize, forKey: "fileSize")
        object.setValue(attachment.duration, forKey: "duration")
        object.setValue(attachment.sortOrder, forKey: "sortOrder")
        CoreDataValueMapper.applySyncFields(
            to: object,
            remoteId: attachment.remoteId,
            createdAt: attachment.createdAt,
            updatedAt: Date(),
            deletedAt: attachment.deletedAt,
            syncStatus: attachment.syncStatus
        )

        try context.save()
        return try mapAttachment(object)
    }

    /// 获取某个业务对象下的所有未删除附件。
    func fetchAttachments(ownerId: UUID, ownerType: AttachmentOwnerType) throws -> [Attachment] {
        let request = baseFetchRequest()
        request.predicate = NSPredicate(format: "deletedAt == nil AND ownerId == %@ AND ownerType == %@", ownerId as CVarArg, ownerType.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true), NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request).map(mapAttachment)
    }

    /// 获取拥有指定类型附件的业务对象 ID 集合。
    /// 列表页用它快速判断记录是否需要展示附件状态。
    func fetchOwnerIdsWithAttachments(ownerType: AttachmentOwnerType, attachmentType: AttachmentType) throws -> Set<UUID> {
        let request = baseFetchRequest()
        request.predicate = NSPredicate(format: "deletedAt == nil AND ownerType == %@ AND type == %@", ownerType.rawValue, attachmentType.rawValue)
        let attachments = try context.fetch(request).map(mapAttachment)
        // 返回 Set 供列表页快速判断哪些记录需要展示附件入口或缩略图。
        return Set(attachments.map(\.ownerId))
    }

    /// 软删除某个业务对象下的所有附件。
    func softDeleteAttachments(ownerId: UUID, ownerType: AttachmentOwnerType) throws {
        try softDeleteMatchingAttachments(ownerId: ownerId, ownerType: ownerType, attachmentType: nil)
    }

    /// 软删除某个业务对象下指定类型的附件。
    func softDeleteAttachments(ownerId: UUID, ownerType: AttachmentOwnerType, attachmentType: AttachmentType) throws {
        try softDeleteMatchingAttachments(ownerId: ownerId, ownerType: ownerType, attachmentType: attachmentType)
    }

    private func softDeleteMatchingAttachments(ownerId: UUID, ownerType: AttachmentOwnerType, attachmentType: AttachmentType?) throws {
        let request = baseFetchRequest()
        var predicates = [
            NSPredicate(format: "deletedAt == nil"),
            NSPredicate(format: "ownerId == %@", ownerId as CVarArg),
            NSPredicate(format: "ownerType == %@", ownerType.rawValue)
        ]

        if let attachmentType {
            predicates.append(NSPredicate(format: "type == %@", attachmentType.rawValue))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let now = Date()

        try context.fetch(request).forEach { object in
            if let path = object.value(forKey: "localFilePath") as? String {
                // 软删除元数据的同时删除本地文件，避免应用沙盒随记录删除持续膨胀。
                storageService.deleteFile(at: path, fileName: object.value(forKey: "fileName") as? String)
            }
            object.setValue(now, forKey: "deletedAt")
            object.setValue(now, forKey: "updatedAt")
            object.setValue(SyncStatus.pendingDelete.rawValue, forKey: "syncStatus")
        }
    }

    private func existingObject(id: UUID) throws -> NSManagedObject? {
        let request = baseFetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func baseFetchRequest() -> NSFetchRequest<NSManagedObject> {
        NSFetchRequest<NSManagedObject>(entityName: "AttachmentEntity")
    }

    private func mapAttachment(_ object: NSManagedObject) throws -> Attachment {
        // 必填字段缺失说明 Core Data 模型或迁移有问题，向上抛出仓储错误便于测试定位。
        guard
            let localId = object.value(forKey: "localId") as? UUID,
            let ownerId = object.value(forKey: "ownerId") as? UUID,
            let ownerTypeRawValue = object.value(forKey: "ownerType") as? String,
            let ownerType = AttachmentOwnerType(rawValue: ownerTypeRawValue),
            let typeRawValue = object.value(forKey: "type") as? String,
            let type = AttachmentType(rawValue: typeRawValue),
            let localFilePath = object.value(forKey: "localFilePath") as? String,
            let createdAt = object.value(forKey: "createdAt") as? Date,
            let updatedAt = object.value(forKey: "updatedAt") as? Date
        else {
            throw RepositoryError.invalidStoredObject(entityName: "AttachmentEntity")
        }

        let fileName = object.value(forKey: "fileName") as? String
        let syncStatusRawValue = object.value(forKey: "syncStatus") as? String
        return Attachment(
            localId: localId,
            remoteId: object.value(forKey: "remoteId") as? String,
            ownerId: ownerId,
            ownerType: ownerType,
            type: type,
            localFilePath: storageService.resolvedPath(for: localFilePath, fileName: fileName),
            remoteURL: object.value(forKey: "remoteURL") as? String,
            fileName: fileName,
            mimeType: object.value(forKey: "mimeType") as? String,
            fileSize: CoreDataValueMapper.int64(object, key: "fileSize"),
            duration: CoreDataValueMapper.double(object, key: "duration"),
            sortOrder: CoreDataValueMapper.int(object, key: "sortOrder") ?? 0,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: object.value(forKey: "deletedAt") as? Date,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}
