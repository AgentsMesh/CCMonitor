import Foundation
import Observation
import ServiceManagement

/// 设置 ViewModel
@Observable
final class SettingsViewModel {
    // MARK: - 预算设置
    var dailyBudget: Double {
        didSet { UserDefaults.standard.set(dailyBudget, forKey: "dailyBudget") }
    }
    var monthlyBudget: Double {
        didSet { UserDefaults.standard.set(monthlyBudget, forKey: "monthlyBudget") }
    }

    // MARK: - 显示偏好
    var showCostInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showCostInMenuBar, forKey: "showCostInMenuBar") }
    }
    var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode") }
    }

    // MARK: - 开机启动
    var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin() }
    }

    // MARK: - 告警
    var budgetAlertEnabled: Bool {
        didSet { UserDefaults.standard.set(budgetAlertEnabled, forKey: "budgetAlertEnabled") }
    }

    enum MenuBarDisplayMode: String, CaseIterable {
        case costOnly = "Cost Only"
        case costAndTokens = "Cost & Tokens"
        case iconOnly = "Icon Only"
    }

    init() {
        // 使用局部变量先计算默认值，避免 @Observable 宏展开后
        // init 中 self 访问未初始化存储属性的编译错误
        let daily = UserDefaults.standard.double(forKey: "dailyBudget")
        let monthly = UserDefaults.standard.double(forKey: "monthlyBudget")

        self.dailyBudget = daily == 0 ? 10.0 : daily
        self.monthlyBudget = monthly == 0 ? 200.0 : monthly
        self.showCostInMenuBar = UserDefaults.standard.object(forKey: "showCostInMenuBar") as? Bool ?? true
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? "") ?? .costOnly
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.budgetAlertEnabled = UserDefaults.standard.object(forKey: "budgetAlertEnabled") as? Bool ?? true
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 回退状态
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
