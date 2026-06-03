import SnapKit
import UIKit

/// 首页概览摘要卡片。
/// 用于展示单个摘要指标及其辅助说明。
final class HomeSummaryCardView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let accessoryLabel = UILabel()
    private var bodyTopToSubtitleConstraint: Constraint?
    private var bodyTopToTitleConstraint: Constraint?

    init(title: String) {
        super.init(frame: .zero)
        setup(title: title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(subtitle: String?, body: String, accessory: String?) {
        configure(subtitle: subtitle, body: body, accessory: accessory, bodyNumberOfLines: 3)
    }

    func configure(subtitle: String?, body: String, accessory: String?, bodyNumberOfLines: Int) {
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle?.isEmpty != false
        bodyTopToSubtitleConstraint?.update(priority: subtitleLabel.isHidden ? .low : .required)
        bodyTopToTitleConstraint?.update(priority: subtitleLabel.isHidden ? .required : .low)
        bodyLabel.text = body
        bodyLabel.numberOfLines = bodyNumberOfLines
        accessoryLabel.text = accessory
        accessoryLabel.isHidden = accessory == nil
    }

    private func setup(title: String) {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderColor = ViewDayTheme.border.cgColor
        layer.borderWidth = 1
        isUserInteractionEnabled = true

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = ViewDayTheme.secondaryText

        bodyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        bodyLabel.textColor = ViewDayTheme.primaryText
        bodyLabel.numberOfLines = 3

        accessoryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        accessoryLabel.textColor = ViewDayTheme.secondaryText

        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(bodyLabel)
        addSubview(accessoryLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        bodyLabel.snp.makeConstraints { make in
            bodyTopToSubtitleConstraint = make.top.equalTo(subtitleLabel.snp.bottom).offset(8).priority(.required).constraint
            bodyTopToTitleConstraint = make.top.equalTo(titleLabel.snp.bottom).offset(10).priority(.low).constraint
            make.leading.trailing.equalToSuperview().inset(16)
        }

        accessoryLabel.snp.makeConstraints { make in
            make.top.equalTo(bodyLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }
    }
}
