import SnapKit
import UIKit

/// 已选图片条的交互回调。
protocol SelectedImageStripViewDelegate: AnyObject {
    func selectedImageStripView(_ view: SelectedImageStripView, didRemoveImageAt index: Int)
}

/// 记录页已选图片横向预览条。
/// 用户可在保存前移除已选图片。
final class SelectedImageStripView: UIView {
    weak var delegate: SelectedImageStripViewDelegate?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var images: [UIImage] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(images: [UIImage]) {
        self.images = images
        rebuild()
        isHidden = images.isEmpty
    }

    private func setup() {
        isHidden = true
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor

        scrollView.showsHorizontalScrollIndicator = false

        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.alignment = .center

        addSubview(scrollView)
        scrollView.addSubview(stackView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
            make.height.equalTo(78)
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }
    }

    private func rebuild() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        images.enumerated().forEach { index, image in
            stackView.addArrangedSubview(makeImageItem(image: image, index: index))
        }
    }

    private func makeImageItem(image: UIImage, index: Int) -> UIView {
        let container = UIView()
        container.snp.makeConstraints { make in
            make.width.height.equalTo(78)
        }

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8

        let removeButton = UIButton(type: .system)
        removeButton.tag = index
        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = .white
        removeButton.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        removeButton.layer.cornerRadius = 11
        removeButton.addTarget(self, action: #selector(removeButtonTapped(_:)), for: .touchUpInside)

        container.addSubview(imageView)
        container.addSubview(removeButton)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        removeButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(4)
            make.width.height.equalTo(22)
        }

        return container
    }

    @objc private func removeButtonTapped(_ sender: UIButton) {
        delegate?.selectedImageStripView(self, didRemoveImageAt: sender.tag)
    }
}
