import Foundation

enum RepositoryError: Error {
    case invalidStoredObject(entityName: String)
}
