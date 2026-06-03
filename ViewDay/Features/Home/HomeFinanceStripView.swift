import SnapKit
import UIKit

/// 首页收支摘要条。
/// 展示当日收入、支出、结余和最近一笔流水。
final class HomeFinanceStripView: UIView {
    private let titleLabel = UILabel()
    private let actionLabel = UILabel()
    private let metricsStackView = UIStackView()
    private let latestLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(income: Decimal, expense: Decimal, balance: Decimal, latest: String?) {
        metricsStackView.arrangedSubviews.forEach { view in
            metricsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        addMetric(title: "收入", value: formatCurrency(income), highlighted: true)
        addMetric(title: "支出", value: formatCurrency(expense), highlighted: false)
        addMetric(title: "结余", value: formatCurrency(balance), highlighted: true)
        latestLabel.text = "最近一笔  \(latest ?? "暂无账单")"
    }

    private func setup() {
        backgroundColor = ViewDayTheme.elevatedCardBackground
        layer.cornerRadius = 10
        layer.borderColor = ViewDayTheme.border.cgColor
        layer.borderWidth = 1
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.045
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)
        isUserInteractionEnabled = true

        titleLabel.text = "今日收支"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        actionLabel.text = "查看详情 >"
        actionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        actionLabel.textColor = ViewDayTheme.secondaryText
        actionLabel.textAlignment = .right

        metricsStackView.axis = .horizontal
        metricsStackView.distribution = .fillEqually
        metricsStackView.spacing = 0

        latestLabel.font = .systemFont(ofSize: 13, weight: .medium)
        latestLabel.textColor = ViewDayTheme.secondaryText
        latestLabel.numberOfLines = 1

        addSubview(titleLabel)
        addSubview(actionLabel)
        addSubview(metricsStackView)
        addSubview(latestLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16)
        }

        actionLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(16)
        }

        metricsStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        latestLabel.snp.makeConstraints { make in
            make.top.equalTo(metricsStackView.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }
    }

    private func addMetric(title: String, value: String, highlighted: Bool) {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = ViewDayTheme.secondaryText

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = highlighted ? ViewDayTheme.accent : ViewDayTheme.primaryText
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(valueLabel)
        metricsStackView.addArrangedSubview(stackView)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }
}
