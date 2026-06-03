import SnapKit
import UIKit

/// 账本月份选择器回调。
protocol LedgerMonthSelectorViewDelegate: AnyObject {
    func ledgerMonthSelectorViewDidTapPrevious(_ view: LedgerMonthSelectorView)
    func ledgerMonthSelectorViewDidTapNext(_ view: LedgerMonthSelectorView)
}

/// 账本月份选择器。
/// 提供上一月、下一月和当前月份展示。
final class LedgerMonthSelectorView: UIView {
    weak var delegate: LedgerMonthSelectorViewDelegate?

    private let previousButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(month: Date) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月"
        titleLabel.text = formatter.string(from: month)
    }

    private func setup() {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor

        previousButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        previousButton.tintColor = ViewDayTheme.primaryText
        previousButton.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)

        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextButton.tintColor = ViewDayTheme.primaryText
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText
        titleLabel.textAlignment = .center

        addSubview(previousButton)
        addSubview(titleLabel)
        addSubview(nextButton)

        previousButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(8)
            make.width.equalTo(44)
        }

        nextButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview().inset(8)
            make.width.equalTo(44)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(previousButton.snp.trailing).offset(8)
            make.trailing.equalTo(nextButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
    }

    @objc private func previousTapped() {
        delegate?.ledgerMonthSelectorViewDidTapPrevious(self)
    }

    @objc private func nextTapped() {
        delegate?.ledgerMonthSelectorViewDidTapNext(self)
    }
}
