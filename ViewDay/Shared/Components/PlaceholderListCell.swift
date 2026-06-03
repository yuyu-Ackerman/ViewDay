import SnapKit
import UIKit

/// 列表空状态占位单元格。
/// 用于日记、账本等列表在无数据时展示简短提示。
final class PlaceholderListCell: UITableViewCell {
    static let reuseIdentifier = "PlaceholderListCell"

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none

        containerView.backgroundColor = ViewDayTheme.cardBackground
        containerView.layer.cornerRadius = 8
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = ViewDayTheme.border.cgColor

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = ViewDayTheme.secondaryText
        subtitleLabel.numberOfLines = 2

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16))
        }

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(14)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.trailing.bottom.equalToSuperview().inset(14)
        }
    }
}
