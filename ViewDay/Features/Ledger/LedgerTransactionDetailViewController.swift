import SnapKit
import UIKit

/// 流水详情控制器。
/// 展示单笔账本流水的金额、分类、地点天气和附件，并提供编辑与删除入口。
final class LedgerTransactionDetailViewController: ViewDayBaseViewController {
    var onDelete: (() -> Void)?
    var onUpdate: (() -> Void)?

    private var transaction: LedgerTransaction
    private let transactionRepository: TransactionRepositoryProtocol
    private let attachmentRepository: AttachmentRepository
    private let imageGridView = AttachmentImageGridView()

    init(
        transaction: LedgerTransaction,
        transactionRepository: TransactionRepositoryProtocol = TransactionRepository(),
        attachmentRepository: AttachmentRepository = AttachmentRepository()
    ) {
        self.transaction = transaction
        self.transactionRepository = transactionRepository
        self.attachmentRepository = attachmentRepository
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "账单详情"
        configureNavigationItems()
        imageGridView.delegate = self
        setupContent()
    }

    private func configureNavigationItems() {
        var items = [
            UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(deleteButtonTapped))
        ]
        if !isFutureTransaction {
            items.append(UIBarButtonItem(title: "编辑", style: .plain, target: self, action: #selector(editButtonTapped)))
        }
        navigationItem.rightBarButtonItems = items
    }

    private func setupContent() {
        let amountCard = InfoCardView(title: transaction.type == .income ? "收入" : "支出")
        amountCard.addRow(title: "金额", value: signedAmountText(), valueColor: transaction.type == .income ? ViewDayTheme.accent : ViewDayTheme.primaryText)
        amountCard.addRow(title: "分类", value: categoryText(transaction.category))
        amountCard.addRow(title: "账户", value: "默认账户")
        amountCard.addRow(title: "时间", value: formattedDate(transaction.transactionDate))
        amountCard.addRow(title: "状态", value: transaction.isDraft ? "草稿" : "已保存")

        let detailCard = HomeSummaryCardView(title: "账单内容")
        detailCard.configure(
            subtitle: transaction.note ?? "无备注",
            body: transaction.detailText ?? "暂无文字描述",
            accessory: locationAndWeatherText()
        )

        let imagePaths = imageAttachmentPaths()

        contentView.addSubview(amountCard)
        contentView.addSubview(detailCard)

        amountCard.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        detailCard.snp.makeConstraints { make in
            make.top.equalTo(amountCard.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        if imagePaths.isEmpty {
            detailCard.snp.makeConstraints { make in
                make.bottom.equalToSuperview().inset(24)
            }
        } else {
            contentView.addSubview(imageGridView)
            imageGridView.configure(imagePaths: imagePaths)
            imageGridView.snp.makeConstraints { make in
                make.top.equalTo(detailCard.snp.bottom).offset(14)
                make.leading.trailing.equalToSuperview().inset(20)
                make.bottom.equalToSuperview().inset(24)
            }
        }
    }

    private func imageAttachmentPaths() -> [String] {
        (try? attachmentRepository.fetchAttachments(ownerId: transaction.localId, ownerType: .transaction))
            .map { attachments in
                attachments.filter { $0.type == .image }.map(\.localFilePath)
            } ?? []
    }

    @objc private func deleteButtonTapped() {
        let alertController = UIAlertController(title: "删除账单？", message: "删除后会同时删除这笔账单下的图片和文字描述，不会影响日记。", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        alertController.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.deleteTransaction()
        })
        present(alertController, animated: true)
    }

    private func deleteTransaction() {
        do {
            try transactionRepository.softDeleteTransaction(id: transaction.localId)
            onDelete?()
            navigationController?.popViewController(animated: true)
        } catch {
            let alertController = UIAlertController(title: "删除失败", message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "好", style: .default))
            present(alertController, animated: true)
        }
    }

    @objc private func editButtonTapped() {
        guard !isFutureTransaction else {
            showFutureEditAlert()
            return
        }

        let editViewController = LedgerTransactionEditViewController(
            transaction: transaction,
            transactionRepository: transactionRepository,
            attachmentRepository: attachmentRepository
        )
        editViewController.onSave = { [weak self] in
            self?.reloadTransaction()
            self?.onUpdate?()
        }
        navigationController?.pushViewController(editViewController, animated: true)
    }

    private func reloadTransaction() {
        do {
            guard let updatedTransaction = try transactionRepository.fetchTransaction(id: transaction.localId) else { return }
            transaction = updatedTransaction
            contentView.subviews.forEach { $0.removeFromSuperview() }
            setupContent()
            configureNavigationItems()
        } catch {
            onUpdate?()
        }
    }

    private var isFutureTransaction: Bool {
        transaction.transactionDate > Date()
    }

    private func showFutureEditAlert() {
        let alertController = UIAlertController(title: "不能编辑未来账单", message: "这笔账单的记录时间还没到。", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "好", style: .default))
        present(alertController, animated: true)
    }

    private func signedAmountText() -> String {
        let prefix = transaction.type == .income ? "+" : "-"
        return "\(prefix)\(formatCurrency(transaction.amount))"
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private func locationAndWeatherText() -> String? {
        let location = transaction.location?.name ?? transaction.location?.district ?? transaction.location?.city
        let weather: String?
        if let snapshot = transaction.weather, let temperature = snapshot.temperature, let condition = snapshot.condition {
            weather = "\(Int(temperature.rounded()))°C \(condition)"
        } else {
            weather = transaction.weather?.condition
        }

        return [location, weather].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension LedgerTransactionDetailViewController: AttachmentImageGridViewDelegate {
    func attachmentImageGridView(_ view: AttachmentImageGridView, didSelectImageAt index: Int, images: [UIImage]) {
        let previewViewController = UINavigationController(rootViewController: ImageGalleryPreviewViewController(images: images, initialIndex: index))
        present(previewViewController, animated: true)
    }
}
