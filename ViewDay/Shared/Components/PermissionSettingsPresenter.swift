import UIKit

/// 权限设置提示工具。
/// 当定位或麦克风权限被拒绝时，引导用户跳转到系统设置。
enum PermissionSettingsPresenter {
    static func presentSettingsAlert(from presenter: UIViewController, title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        alertController.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        presenter.present(alertController, animated: true)
    }
}
