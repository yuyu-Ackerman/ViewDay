import Foundation

/// 将天气服务错误转换为面向用户的提示文案。
/// 自动获取失败时始终保留手动填写天气的后续路径。
func weatherFailureMessage(_ error: Error) -> String {
    if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
        return "\(description) 你仍然可以手动填写天气。"
    }

    return "自动获取失败，你仍然可以手动填写天气。"
}
