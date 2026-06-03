//
//  SceneDelegate.swift
//  ViewDay
//
//  Created by 小余 on 2026/5/29.
//

import UIKit

/// Scene 生命周期入口。
/// 负责创建主窗口并挂载应用的主 Tab 容器。
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainTabBarController()
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // 进入后台时提交主上下文，降低用户离开应用时丢失最近编辑的风险。
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }
}
