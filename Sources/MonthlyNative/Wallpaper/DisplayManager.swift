import AppKit
import CoreGraphics
import ColorSync

struct Display: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let displayID: CGDirectDisplayID
    let logicalSize: CGSize
    let pixelSize: CGSize
    var resolution: String { "\(Int(pixelSize.width)) × \(Int(pixelSize.height))" }

    @MainActor static func connected() -> [Display] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let displayID = CGDirectDisplayID(number.uint32Value)
            let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
            let identifier = uuid.map { CFUUIDCreateString(nil, $0) as String } ?? "display-\(displayID)"
            let backing = screen.convertRectToBacking(screen.frame).size
            return Display(id: identifier, name: screen.localizedName, displayID: displayID,
                           logicalSize: screen.frame.size, pixelSize: backing)
        }
    }

    @MainActor var screen: NSScreen? {
        Self.connected().first { $0.id == id && $0 == self }.flatMap { matched in
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == matched.displayID
        }
        }
    }
}
