import ServiceManagement

struct LoginItemController {
    var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .notRegistered: .off
        case .enabled: .on
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            let status = SMAppService.mainApp.status
            if status != .enabled && status != .requiresApproval { try SMAppService.mainApp.register() }
        } else if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
