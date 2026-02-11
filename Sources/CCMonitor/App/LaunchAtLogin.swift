import Foundation
import ServiceManagement

/// 开机启动管理
enum LaunchAtLogin {
    /// 当前是否启用开机启动
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 启用开机启动
    static func enable() throws {
        try SMAppService.mainApp.register()
    }

    /// 禁用开机启动
    static func disable() throws {
        try SMAppService.mainApp.unregister()
    }

    /// 切换开机启动状态
    static func toggle() throws {
        if isEnabled {
            try disable()
        } else {
            try enable()
        }
    }
}
