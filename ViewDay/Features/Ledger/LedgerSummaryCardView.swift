import SnapKit
import UIKit

/// 账本月度摘要卡片。
/// 展示收入、支出和结余等核心统计指标。
final class LedgerSummaryCardView: UIView {
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(month: Date, income: Decimal, expense: Decimal, balance: Decimal) {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        addMetric(title: "收入", value: formatCurrency(income), highlighted: true)
        addMetric(title: "支出", value: formatCurrency(expense), highlighted: false)
        addMetric(title: "结余", value: formatCurrency(balance), highlighted: true)
    }

    private func setup() {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 0

        addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(14)
            make.height.equalTo(48)
        }
    }

    private func addMetric(title: String, value: String, highlighted: Bool) {
        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = ViewDayTheme.secondaryText

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 17, weight: .bold)
        valueLabel.textColor = highlighted ? ViewDayTheme.accent : ViewDayTheme.primaryText
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.72

        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        valueLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(5)
            make.leading.trailing.bottom.equalToSuperview()
        }
        stackView.addArrangedSubview(container)
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
