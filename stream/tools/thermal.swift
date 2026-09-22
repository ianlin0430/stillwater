import Foundation
let names = ["nominal", "fair", "serious", "critical"]
let state = ProcessInfo.processInfo.thermalState.rawValue
print("{\"thermal_state\":\"\(names[min(state,3)])\",\"low_power_mode\":\(ProcessInfo.processInfo.isLowPowerModeEnabled)}")
