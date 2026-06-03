import SnapKit
import UIKit

/// 账本分类选择卡片回调。
protocol TransactionCategoryPickerCardViewDelegate: AnyObject {
    func transactionCategoryPickerCardView(_ view: TransactionCategoryPickerCardView, didSelect category: TransactionCategory)
}

/// 账本分类选择卡片。
/// 根据收入或支出方向展示可用分类。
final class TransactionCategoryPickerCardView: UIView {
    weak var delegate: TransactionCategoryPickerCardViewDelegate?

    private let titleLabel = UILabel()
    private let collectionView: UICollectionView
    private var type: TransactionType
    private(set) var selectedCategory: TransactionCategory
    private var categories: [TransactionCategory] {
        TransactionCategory.available(for: type)
    }

    init(type: TransactionType = .expense) {
        self.type = type
        selectedCategory = TransactionCategory.available(for: type).first ?? .other

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func updateType(_ type: TransactionType) {
        self.type = type
        selectedCategory = TransactionCategory.available(for: type).first ?? .other
        collectionView.reloadData()
        delegate?.transactionCategoryPickerCardView(self, didSelect: selectedCategory)
    }

    func configure(type: TransactionType, selectedCategory: TransactionCategory) {
        self.type = type
        if TransactionCategory.available(for: type).contains(selectedCategory) {
            self.selectedCategory = selectedCategory
        } else {
            self.selectedCategory = TransactionCategory.available(for: type).first ?? .other
        }
        collectionView.reloadData()
        delegate?.transactionCategoryPickerCardView(self, didSelect: self.selectedCategory)
    }

    private func setup() {
        backgroundColor = ViewDayTheme.elevatedCardBackground
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor

        titleLabel.text = "分类"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CategoryCell.self, forCellWithReuseIdentifier: CategoryCell.reuseIdentifier)

        addSubview(titleLabel)
        addSubview(collectionView)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
            make.height.equalTo(148)
        }
    }

    private func title(for category: TransactionCategory) -> String {
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

    private func symbolName(for category: TransactionCategory) -> String {
        switch category {
        case .food:
            return "fork.knife"
        case .transport:
            return "car"
        case .shopping:
            return "bag"
        case .entertainment:
            return "gamecontroller"
        case .home:
            return "house"
        case .medical:
            return "cross.case"
        case .salary:
            return "creditcard"
        case .partTime:
            return "briefcase"
        case .gift:
            return "gift"
        case .investment:
            return "chart.line.uptrend.xyaxis"
        case .other:
            return "ellipsis"
        }
    }
}

extension TransactionCategoryPickerCardView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        categories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CategoryCell.reuseIdentifier, for: indexPath) as? CategoryCell
        let category = categories[indexPath.item]
        cell?.configure(title: title(for: category), symbolName: symbolName(for: category), isSelected: category == selectedCategory)
        return cell ?? UICollectionViewCell()
    }
}

extension TransactionCategoryPickerCardView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedCategory = categories[indexPath.item]
        collectionView.reloadData()
        delegate?.transactionCategoryPickerCardView(self, didSelect: selectedCategory)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = floor((collectionView.bounds.width - 24) / 4)
        return CGSize(width: width, height: 66)
    }
}

private final class CategoryCell: UICollectionViewCell {
    static let reuseIdentifier = "CategoryCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(title: String, symbolName: String, isSelected: Bool) {
        iconView.image = UIImage(systemName: symbolName)
        titleLabel.text = title
        iconView.tintColor = isSelected ? ViewDayTheme.accent : ViewDayTheme.iconSecondary
        titleLabel.textColor = isSelected ? ViewDayTheme.accent : ViewDayTheme.secondaryText
        contentView.backgroundColor = isSelected ? ViewDayTheme.accent.withAlphaComponent(0.12) : ViewDayTheme.controlBackground
        contentView.layer.borderColor = (isSelected ? ViewDayTheme.accent : ViewDayTheme.border).cgColor
    }

    private func setup() {
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1

        iconView.contentMode = .scaleAspectFill

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textAlignment = .center

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(10)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(5)
            make.leading.trailing.bottom.equalToSuperview().inset(6)
        }
    }
}
