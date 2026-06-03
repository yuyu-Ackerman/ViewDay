import SnapKit
import UIKit

/// 账本分类占比条视图。
/// 用横向条展示本月支出分类金额和占比。
final class LedgerCategoryBarsView: UIView {
    private let titleLabel = UILabel()
    private let donutView = CategoryDonutView()
    private let legendStackView = UIStackView()
    private let emptyStateView = LedgerEmptyStateView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(title: String, summaries: [CategorySummary]) {
        titleLabel.text = title
        legendStackView.arrangedSubviews.forEach { view in
            legendStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let visibleSummaries = Array(summaries.prefix(5))
        donutView.configure(summaries: visibleSummaries)
        donutView.isHidden = visibleSummaries.isEmpty
        legendStackView.isHidden = visibleSummaries.isEmpty
        emptyStateView.isHidden = !visibleSummaries.isEmpty

        guard !visibleSummaries.isEmpty else {
            emptyStateView.configure(title: "暂无分类数据", subtitle: "添加几笔账单后，这里会显示支出或收入占比。")
            return
        }

        visibleSummaries.enumerated().forEach { index, summary in
            legendStackView.addArrangedSubview(CategoryLegendRow(summary: summary, color: CategoryDonutPalette.color(at: index)))
        }
    }

    private func setup() {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.05
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        legendStackView.axis = .vertical
        legendStackView.spacing = 10

        let contentStackView = UIStackView(arrangedSubviews: [donutView, legendStackView])
        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.spacing = 18

        addSubview(titleLabel)
        addSubview(contentStackView)
        addSubview(emptyStateView)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }

        donutView.snp.makeConstraints { make in
            make.width.height.equalTo(116)
        }

        contentStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }

        emptyStateView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
            make.height.greaterThanOrEqualTo(84)
        }
    }
}

private final class CategoryDonutView: UIView {
    private var summaries: [CategorySummary] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(summaries: [CategorySummary]) {
        self.summaries = summaries
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let lineWidth: CGFloat = 18
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let basePath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        ViewDayTheme.background.setStroke()
        basePath.lineWidth = lineWidth
        basePath.lineCapStyle = .round
        basePath.stroke()

        guard !summaries.isEmpty else { return }

        var startAngle = -CGFloat.pi / 2
        summaries.enumerated().forEach { index, summary in
            let gap: CGFloat = summaries.count > 1 ? 0.04 : 0
            let value = max(0.02, min(CGFloat(summary.percentage), 1))
            let endAngle = startAngle + value * CGFloat.pi * 2 - gap
            let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            CategoryDonutPalette.color(at: index).setStroke()
            path.lineWidth = lineWidth
            path.lineCapStyle = .round
            path.stroke()
            startAngle = endAngle + gap
        }

        let total = summaries.map(\.amount).reduce(Decimal.zero, +)
        let title = "合计" as NSString
        let value = compactCurrency(total) as NSString
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: ViewDayTheme.secondaryText
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: ViewDayTheme.primaryText
        ]
        let titleSize = title.size(withAttributes: titleAttributes)
        let valueSize = value.size(withAttributes: valueAttributes)
        title.draw(at: CGPoint(x: rect.midX - titleSize.width / 2, y: rect.midY - 18), withAttributes: titleAttributes)
        value.draw(at: CGPoint(x: rect.midX - valueSize.width / 2, y: rect.midY - 2), withAttributes: valueAttributes)
    }

    private func compactCurrency(_ amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        if abs(value) >= 10000 {
            return String(format: "¥%.1f万", value / 10000)
        }
        return String(format: "¥%.0f", value)
    }
}

private final class CategoryLegendRow: UIView {
    private let dotView = UIView()
    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let percentLabel = UILabel()

    init(summary: CategorySummary, color: UIColor) {
        super.init(frame: .zero)
        setup(color: color)
        configure(summary: summary)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func setup(color: UIColor) {
        dotView.backgroundColor = color
        dotView.layer.cornerRadius = 4

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        amountLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        amountLabel.textColor = ViewDayTheme.primaryText
        amountLabel.textAlignment = .right
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.75

        percentLabel.font = .systemFont(ofSize: 12, weight: .medium)
        percentLabel.textColor = ViewDayTheme.secondaryText
        percentLabel.textAlignment = .right

        addSubview(dotView)
        addSubview(titleLabel)
        addSubview(amountLabel)
        addSubview(percentLabel)

        dotView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(8)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(dotView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
        }

        amountLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
            make.trailing.equalTo(percentLabel.snp.leading).offset(-10)
            make.centerY.equalToSuperview()
        }

        percentLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(34)
        }

        snp.makeConstraints { make in
            make.height.equalTo(20)
        }
    }

    private func configure(summary: CategorySummary) {
        titleLabel.text = categoryText(summary.category)
        amountLabel.text = formatCurrency(summary.amount)
        percentLabel.text = "\(Int((summary.percentage * 100).rounded()))%"
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

private enum CategoryDonutPalette {
    private static let colors: [UIColor] = [
        UIColor(red: 0.714, green: 1.0, blue: 0.231, alpha: 1.0),
        UIColor(red: 0.357, green: 0.659, blue: 1.0, alpha: 1.0),
        UIColor(red: 0.306, green: 0.827, blue: 0.424, alpha: 1.0),
        UIColor(red: 1.0, green: 0.641, blue: 0.086, alpha: 1.0),
        UIColor(red: 0.65, green: 0.69, blue: 0.75, alpha: 1.0)
    ]

    static func color(at index: Int) -> UIColor {
        colors[index % colors.count]
    }
}

private final class LedgerEmptyStateView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
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
        backgroundColor = ViewDayTheme.background
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor

        iconView.image = UIImage(systemName: "chart.pie")
        iconView.tintColor = ViewDayTheme.iconSecondary
        iconView.contentMode = .scaleAspectFill

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.textColor = ViewDayTheme.secondaryText
        subtitleLabel.numberOfLines = 2

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(16)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.trailing.equalTo(titleLabel)
            make.bottom.lessThanOrEqualToSuperview().inset(16)
        }
    }
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
