import SnapKit
import UIKit

/// 记录页附件操作区回调。
protocol AttachmentActionGridViewDelegate: AnyObject {
    func attachmentActionGridViewDidTapImages(_ view: AttachmentActionGridView)
    func attachmentActionGridViewDidTapAudio(_ view: AttachmentActionGridView)
    func attachmentActionGridViewDidTapTags(_ view: AttachmentActionGridView)
}

/// 记录页附件操作网格。
/// 提供图片、地点、语音和标签入口，并展示已选数量徽标。
final class AttachmentActionGridView: UIView {
    weak var delegate: AttachmentActionGridViewDelegate?

    private let stackView = UIStackView()
    private var badgeLabels: [Int: UILabel] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layer.borderColor = ViewDayTheme.border.cgColor
        badgeLabels.values.forEach { label in
            label.layer.borderColor = ViewDayTheme.cardBackground.cgColor
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(10)
            make.height.equalTo(42)
        }

        [
            ("photo", "图片"),
            ("mic", "语音"),
            ("tag", "标签")
        ].enumerated().forEach { index, item in
            let button = makeButton(symbolName: item.0, title: item.1, index: index)
            button.tag = index
            button.addTarget(self, action: #selector(actionButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
    }

    func configureBadges(imageCount: Int, audioCount: Int, tagCount: Int) {
        updateBadge(at: 0, count: imageCount)
        updateBadge(at: 1, count: audioCount)
        updateBadge(at: 2, count: tagCount)
    }

    private func makeButton(symbolName: String, title: String, index: Int) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbolName)
        configuration.imagePlacement = .top
        configuration.imagePadding = 3
        configuration.title = title
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
        configuration.baseForegroundColor = ViewDayTheme.primaryText

        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        let badgeLabel = makeBadgeLabel(for: index)
        button.addSubview(badgeLabel)
        badgeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(1)
            make.centerX.equalToSuperview().offset(18)
            make.width.height.equalTo(20)
        }
        return button
    }

    private func makeBadgeLabel(for index: Int) -> UILabel {
        let label = UILabel()
        label.isHidden = true
        label.isOpaque = true
        label.backgroundColor = ViewDayTheme.accent
        label.textColor = .black
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.layer.borderWidth = 2
        label.layer.borderColor = ViewDayTheme.cardBackground.cgColor
        label.layer.masksToBounds = true
        label.layer.zPosition = 10
        badgeLabels[index] = label
        return label
    }

    private func updateBadge(at index: Int, count: Int) {
        guard let label = badgeLabels[index] else { return }
        label.isHidden = count <= 0
        label.text = count > 9 ? "9+" : "\(count)"
    }

    @objc private func actionButtonTapped(_ sender: UIButton) {
        if sender.tag == 0 {
            delegate?.attachmentActionGridViewDidTapImages(self)
        } else if sender.tag == 1 {
            delegate?.attachmentActionGridViewDidTapAudio(self)
        } else if sender.tag == 2 {
            delegate?.attachmentActionGridViewDidTapTags(self)
        }
    }
}
