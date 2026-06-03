import SnapKit
import UIKit

/// 附件图片网格的交互回调。
protocol AttachmentImageGridViewDelegate: AnyObject {
    func attachmentImageGridView(_ view: AttachmentImageGridView, didSelectImageAt index: Int, images: [UIImage])
}

/// 附件图片预览网格。
/// 用于详情页展示记录关联图片，并把点击事件交给外层打开预览。
final class AttachmentImageGridView: UIView {
    weak var delegate: AttachmentImageGridViewDelegate?

    private let titleLabel = UILabel()
    private let collectionView: UICollectionView
    private var collectionHeightConstraint: Constraint?
    private var images: [UIImage] = []

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(title: String = "图片", imagePaths: [String]) {
        titleLabel.text = title
        images = imagePaths.compactMap { UIImage(contentsOfFile: $0) }
        collectionView.reloadData()
        updateCollectionHeight()
        isHidden = images.isEmpty
    }

    private func setup() {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.reuseIdentifier)

        addSubview(titleLabel)
        addSubview(collectionView)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
            collectionHeightConstraint = make.height.equalTo(0).constraint
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCollectionHeight()
    }

    private func updateCollectionHeight() {
        guard !images.isEmpty else {
            collectionHeightConstraint?.update(offset: 0)
            return
        }

        let itemWidth = gridItemWidth()
        let rowCount = Int(ceil(Double(images.count) / 3.0))
        let height = CGFloat(rowCount) * itemWidth + CGFloat(max(0, rowCount - 1)) * 8
        collectionHeightConstraint?.update(offset: height)
        collectionView.collectionViewLayout.invalidateLayout()
    }

    private func gridItemWidth() -> CGFloat {
        // 初次布局时 bounds 可能仍为 0，使用屏幕宽度兜底避免高度被错误计算成 0。
        let availableWidth = max(bounds.width - 32, UIScreen.main.bounds.width - 72)
        return floor((availableWidth - 16) / 3)
    }
}

// MARK: - UICollectionViewDataSource

extension AttachmentImageGridView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseIdentifier, for: indexPath) as? ImageCell
        cell?.configure(image: images[indexPath.item])
        return cell ?? UICollectionViewCell()
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension AttachmentImageGridView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.attachmentImageGridView(self, didSelectImageAt: indexPath.item, images: images)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = floor((collectionView.bounds.width - 16) / 3)
        return CGSize(width: width, height: width)
    }
}

private final class ImageCell: UICollectionViewCell {
    static let reuseIdentifier = "ImageCell"

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = ViewDayTheme.background
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(image: UIImage) {
        imageView.image = image
    }
}
