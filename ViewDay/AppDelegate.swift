//
//  AppDelegate.swift
//  ViewDay
//
//  Created by 小余 on 2026/5/29.
//

import UIKit
import CoreData

/// 应用生命周期入口。
/// 负责启动时补齐默认数据，并桥接 Core Data 入口给系统模板调用。
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        seedDefaultData()
        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    // MARK: - Core Data

    lazy var persistentContainer: NSPersistentContainer = {
        CoreDataStack.shared.persistentContainer
    }()

    func saveContext() {
        CoreDataStack.shared.saveContext()
    }

    private func seedDefaultData() {
        do {
            try DefaultDataSeeder(context: persistentContainer.viewContext).seedIfNeeded()
        } catch {
            assertionFailure("Failed to seed default data: \(error)")
        }
    }

}
