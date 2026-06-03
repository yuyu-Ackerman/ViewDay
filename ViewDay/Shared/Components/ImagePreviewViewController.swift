import SnapKit
import UIKit

/// 单张图片预览控制器。
/// 用于附件缩略图点击后的全屏查看。
final class ImagePreviewViewController: UIViewController {
    private let image: UIImage
    private let imageView = UIImageView()

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "关闭", style: .done, target: self, action: #selector(close))

        imageView.image = image
        imageView.contentMode = .scaleAspectFill

        view.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
