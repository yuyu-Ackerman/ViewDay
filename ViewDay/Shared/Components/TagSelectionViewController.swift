import SnapKit
import UIKit

/// 标签选择控制器。
/// 用于记录页选择或创建日记标签，并通过回调返回最终选中集合。
final class TagSelectionViewController: UIViewController {
    var onSave: (([Tag]) -> Void)?

    private let tagRepository: TagRepository
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateLabel = UILabel()

    private var tags: [Tag] = []
    private var selectedTagIds: Set<UUID>

    init(selectedTags: [Tag], tagRepository: TagRepository = TagRepository()) {
        self.tagRepository = tagRepository
        selectedTagIds = Set(selectedTags.map(\.localId))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "选择标签"
        view.backgroundColor = ViewDayTheme.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(doneButtonTapped)),
            UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: self, action: #selector(addButtonTapped))
        ]

        setupTableView()
        setupEmptyState()
        reloadTags()
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TagCell")

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func setupEmptyState() {
        emptyStateLabel.text = "还没有标签"
        emptyStateLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        emptyStateLabel.textColor = ViewDayTheme.secondaryText
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.isHidden = true

        view.addSubview(emptyStateLabel)
        emptyStateLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
        }
    }

    private func reloadTags() {
        do {
            tags = try tagRepository.fetchAllTags()
            tableView.reloadData()
            updateEmptyState()
        } catch {
            tags = []
            tableView.reloadData()
            updateEmptyState()
        }
    }

    private func updateEmptyState() {
        emptyStateLabel.isHidden = !tags.isEmpty
        tableView.isHidden = tags.isEmpty
    }

    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }

    @objc private func doneButtonTapped() {
        let selectedTags = tags.filter { selectedTagIds.contains($0.localId) }
        onSave?(selectedTags)
        dismiss(animated: true)
    }

    @objc private func addButtonTapped() {
        let alertController = UIAlertController(title: "新建标签", message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "例如：散步、工作、家人"
            textField.returnKeyType = .done
        }
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        alertController.addAction(UIAlertAction(title: "添加", style: .default) { [weak self, weak alertController] _ in
            guard let self else { return }
            let name = alertController?.textFields?.first?.text ?? ""
            do {
                let tag = try self.tagRepository.saveTag(name: name)
                self.selectedTagIds.insert(tag.localId)
                self.reloadTags()
            } catch {
                self.showAlert(title: "添加失败", message: "请输入有效标签名称。")
            }
        })
        present(alertController, animated: true)
    }

    private func showAlert(title: String, message: String?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "好", style: .default))
        present(alertController, animated: true)
    }
}

extension TagSelectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tags.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TagCell", for: indexPath)
        let tag = tags[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = tag.name
        content.textProperties.color = ViewDayTheme.primaryText
        cell.contentConfiguration = content
        cell.backgroundColor = ViewDayTheme.background
        cell.tintColor = ViewDayTheme.iconPrimary
        cell.accessoryType = selectedTagIds.contains(tag.localId) ? .checkmark : .none
        return cell
    }
}

extension TagSelectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let tag = tags[indexPath.row]
        if selectedTagIds.contains(tag.localId) {
            selectedTagIds.remove(tag.localId)
        } else {
            selectedTagIds.insert(tag.localId)
        }
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
