import SnapKit
import UIKit

/// ViewDay 页面基类。
/// 提供统一背景色和可垂直滚动的内容容器，适合由卡片组件堆叠组成的页面。
class ViewDayBaseViewController: UIViewController {
    /// 页面滚动容器。
    let scrollView = UIScrollView()
    /// 所有子视图的布局根节点，宽度固定等于滚动视图宽度。
    let contentView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ViewDayTheme.background
        scrollView.showsVerticalScrollIndicator = false
        setupScrollLayout()
    }

    /// 建立统一滚动布局。
    /// 子类只需要把内容添加到 `contentView` 并约束底部，即可得到正确的滚动范围。
    func setupScrollLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        scrollView.alwaysBounceVertical = true
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }
    }
}
