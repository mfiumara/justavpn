import NetworkExtension

public struct OnDemandRulesBuilder {
    public var killSwitch: Bool
    public var autoConnect: Bool

    public init(killSwitch: Bool = false, autoConnect: Bool = false) {
        self.killSwitch = killSwitch
        self.autoConnect = autoConnect
    }

    public func build() -> (rules: [NEOnDemandRule], enabled: Bool) {
        guard killSwitch || autoConnect else {
            return ([], false)
        }

        // Both kill switch and auto-connect use NEOnDemandRuleConnect.
        // The kill switch is effectively "always reconnect if VPN drops",
        // which is the same as auto-connect on all interfaces.
        let connectRule = NEOnDemandRuleConnect()
        connectRule.interfaceTypeMatch = .any
        return ([connectRule], true)
    }
}
