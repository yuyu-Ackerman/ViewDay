import UIKit

/// 附件文件存储错误。
enum AttachmentStorageError: Error {
    /// 图片无法编码成 JPEG 数据。
    case invalidImageData
    /// 系统 Documents 目录不可用。
    case documentsDirectoryUnavailable
}

/// 本地附件文件存储服务。
/// 仓储层只保存路径和元数据，真实文件由该服务写入 Documents/Attachments。
final class AttachmentStorageService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// 将图片压缩为 JPEG 并保存到附件目录。
    ///
    /// - Parameter image: 用户选择或拍摄的图片。
    /// - Returns: 可写入附件实体的路径、文件名和文件大小。
    func saveImage(_ image: UIImage) throws -> (path: String, fileName: String, fileSize: Int64) {
        guard let data = image.jpegData(compressionQuality: 0.86) else {
            throw AttachmentStorageError.invalidImageData
        }

        let directory = try attachmentsDirectory()
        let fileName = "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)

        return (url.path, fileName, Int64(data.count))
    }

    func resolvedPath(for path: String, fileName: String?) -> String {
        if fileManager.fileExists(atPath: path) {
            return path
        }

        // 兼容沙盒路径变化：优先用保存的文件名在当前 Documents 目录下重新定位。
        guard let fileName else { return path }
        guard let directory = try? attachmentsDirectory() else { return path }
        let currentPath = directory.appendingPathComponent(fileName).path
        return fileManager.fileExists(atPath: currentPath) ? currentPath : path
    }

    func deleteFile(at path: String) {
        deleteFile(at: path, fileName: nil)
    }

    func deleteFile(at path: String, fileName: String?) {
        let resolvedPath = resolvedPath(for: path, fileName: fileName)
        guard fileManager.fileExists(atPath: resolvedPath) else { return }
        try? fileManager.removeItem(atPath: resolvedPath)
    }

    private func attachmentsDirectory() throws -> URL {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw AttachmentStorageError.documentsDirectoryUnavailable
        }

        let directory = documentsURL.appendingPathComponent("Attachments", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }
}
