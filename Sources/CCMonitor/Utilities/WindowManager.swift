import AppKit
import SwiftUI

/// 窗口管理器
/// 组合 AppKit 窗口查找 + SwiftUI OpenWindowAction 两级策略：
/// - 已创建过的窗口：直接用 AppKit 激活（makeKeyAndOrderFront）
/// - 首次打开的窗口：通过 SwiftUI openWindow(id:) 触发懒创建
///
/// openWindowAction 由 MenuBarView 在 Button action 中注入，
/// 因为 MenuBarExtra(.window) 的 content 是常驻活跃的 SwiftUI 视图树
@MainActor
enum WindowManager {

    /// 由 MenuBarView 注入的 SwiftUI openWindow action
    static var openWindowAction: OpenWindowAction?

    static func openDashboard() {
        openWindow(id: "dashboard")
    }

    static func openSettings() {
        openWindow(id: "settings")
    }

    // MARK: - Core

    private static func openWindow(id: String) {
        // 1. 激活应用到前台
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // 2. 先找已存在的窗口（之前创建过的）
        if let existing = NSApp.windows.first(where: {
            $0.identifier?.rawValue.contains(id) == true
        }) {
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            return
        }

        // 3. 窗口尚未创建 → 通过 SwiftUI action 触发懒创建
        guard let action = openWindowAction else {
            NSLog("⚠️ WindowManager: openWindowAction not injected, cannot open \(id)")
            return
        }

        action(id: id)

        // 4. 给 SwiftUI 时间创建窗口后，确保它获得焦点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if let window = NSApp.windows.first(where: {
                $0.identifier?.rawValue.contains(id) == true
            }) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    /// 所有业务窗口关闭后恢复 accessory 模式
    static func deactivateApp() {
        let hasVisibleWindows = NSApp.windows.contains { window in
            window.isVisible &&
            window.styleMask.contains(.titled) &&
            !window.title.isEmpty
        }
        if !hasVisibleWindows {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
