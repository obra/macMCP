import Foundation
import AppKit

print("Checking accessibility permissions...")
let hasPermissions = AXIsProcessTrusted()
print("Accessibility permissions granted: \(hasPermissions)")

if !hasPermissions {
    print("To grant permissions:")
    print("1. Go to System Settings > Privacy & Security > Accessibility")
    print("2. Add Terminal.app to the list of allowed applications")
}