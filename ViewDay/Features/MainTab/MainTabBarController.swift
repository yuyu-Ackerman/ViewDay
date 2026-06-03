import UIKit

/// 应用主 Tab 容器。
/// 负责组装首页、日记、记录和账本四个主入口。
final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAppearance()
        setupViewControllers()
    }

    private func setupAppearance() {
        tabBar.tintColor = ViewDayTheme.accent
        tabBar.unselectedItemTintColor = ViewDayTheme.secondaryText

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = ViewDayTheme.elevatedCardBackground
        appearance.shadowColor = ViewDayTheme.border
        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance].forEach { itemAppearance in
            itemAppearance.normal.iconColor = ViewDayTheme.iconSecondary
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: ViewDayTheme.secondaryText]
            itemAppearance.selected.iconColor = ViewDayTheme.accent
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: ViewDayTheme.accent]
        }
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    private func setupViewControllers() {
        viewControllers = [
            MainTabBarController.makeNavigationController(rootViewController: HomeViewController(), title: "日历", symbolName: "calendar"),
            MainTabBarController.makeNavigationController(rootViewController: DiaryListViewController(), title: "日记", symbolName: "book"),
            MainTabBarController.makeNavigationController(rootViewController: RecordViewController(), title: "记录", symbolName: "chart.bar"),
            MainTabBarController.makeNavigationController(rootViewController: LedgerViewController(), title: "账本", symbolName: "wallet.pass")
        ]
    }

    static func makeNavigationController(rootViewController: UIViewController, title: String, symbolName: String) -> UINavigationController {
        rootViewController.title = title
        rootViewController.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: symbolName), selectedImage: UIImage(systemName: "\(symbolName).fill"))

        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.navigationBar.prefersLargeTitles = false
        navigationController.navigationBar.tintColor = ViewDayTheme.iconPrimary

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.largeTitleTextAttributes = [.foregroundColor: ViewDayTheme.primaryText]
        appearance.titleTextAttributes = [.foregroundColor: ViewDayTheme.primaryText]
        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.compactAppearance = appearance

        return navigationController
    }
}
