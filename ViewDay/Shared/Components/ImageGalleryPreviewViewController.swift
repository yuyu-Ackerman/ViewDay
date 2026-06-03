import SnapKit
import UIKit

/// 多图画廊预览控制器。
/// 支持从指定图片开始浏览一组附件图片。
final class ImageGalleryPreviewViewController: UIViewController {
    private let images: [UIImage]
    private let initialIndex: Int
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let pageLabel = UILabel()

    init(images: [UIImage], initialIndex: Int) {
        self.images = images
        self.initialIndex = initialIndex
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
        setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let x = CGFloat(initialIndex) * scrollView.bounds.width
        scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: false)
        updatePageLabel()
    }

    private func setup() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self

        stackView.axis = .horizontal
        stackView.spacing = 0

        pageLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        pageLabel.textColor = .white
        pageLabel.textAlignment = .center

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        view.addSubview(pageLabel)

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(scrollView.snp.height)
        }

        images.forEach { image in
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            stackView.addArrangedSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.width.equalTo(scrollView.snp.width)
            }
        }

        pageLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
        }
    }

    private func updatePageLabel() {
        guard !images.isEmpty, scrollView.bounds.width > 0 else {
            pageLabel.text = nil
            return
        }

        let index = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        pageLabel.text = "\(min(max(index, 0), images.count - 1) + 1) / \(images.count)"
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

extension ImageGalleryPreviewViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updatePageLabel()
    }
}
