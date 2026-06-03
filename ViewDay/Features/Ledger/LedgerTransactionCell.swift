import SnapKit
import UIKit

/// 账本流水列表单元格。
/// 展示分类、备注、日期和收支金额。
final class LedgerTransactionCell: UITableViewCell {
    static let reuseIdentifier = "LedgerTransactionCell"

    private let iconContainerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let amountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(with transaction: LedgerTransaction) {
        titleLabel.text = transaction.isDraft ? "草稿 · \(categoryText(transaction.category))" : categoryText(transaction.category)
        subtitleLabel.text = transaction.note ?? timeText(transaction.transactionDate)
        let prefix = transaction.type == .income ? "+" : "-"
        amountLabel.text = "\(prefix)\(formatCurrency(transaction.amount))"
        amountLabel.textColor = transaction.type == .income ? ViewDayTheme.accent : ViewDayTheme.primaryText
        iconImageView.image = UIImage(systemName: iconName(transaction.category))
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none

        iconContainerView.backgroundColor = ViewDayTheme.controlBackground
        iconContainerView.layer.cornerRadius = 8

        iconImageView.tintColor = ViewDayTheme.iconPrimary
        iconImageView.contentMode = .scaleAspectFill

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = ViewDayTheme.secondaryText

        amountLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        amountLabel.textAlignment = .right
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentView.addSubview(iconContainerView)
        iconContainerView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(amountLabel)

        iconContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(38)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalTo(iconContainerView.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(amountLabel.snp.leading).offset(-12)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel)
            make.trailing.lessThanOrEqualTo(amountLabel.snp.leading).offset(-12)
            make.bottom.equalToSuperview().inset(10)
        }

        amountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }

    private func categoryText(_ category: TransactionCategory) -> String {
        switch category {
        case .food: return "餐饮"
        case .transport: return "交通"
        case .shopping: return "购物"
        case .entertainment: return "娱乐"
        case .home: return "居家"
        case .medical: return "医疗"
        case .salary: return "工资"
        case .partTime: return "兼职"
        case .gift: return "红包"
        case .investment: return "理财"
        case .other: return "其他"
        }
    }

    private func iconName(_ category: TransactionCategory) -> String {
        switch category {
        case .food: return "fork.knife"
        case .transport: return "car"
        case .shopping: return "bag"
        case .entertainment: return "gamecontroller"
        case .home: return "house"
        case .medical: return "cross.case"
        case .salary: return "creditcard"
        case .partTime: return "briefcase"
        case .gift: return "gift"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .other: return "ellipsis"
        }
    }
}
