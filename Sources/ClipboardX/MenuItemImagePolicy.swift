import AppKit
import ObjectiveC

/// Suppresses macOS 26+ automatic “action” symbol images (e.g. gear on Settings…) on
/// `NSMenuItem`s while still showing images we assign on purpose (e.g. app icon, thumbnail).
///
/// AppKit can inject template/SF images for semantically named items even when `image == nil`
/// from our code. We only restore the real `image` getter for rows marked explicit.
enum MenuItemImagePolicy {
    private static var explicitImageKey: UInt8 = 0
    private static let explicitImagePointer = UnsafeRawPointer(&explicitImageKey)
    private static var installed = false
    private static var originalImageIMP: IMP?

    /// Call once early in launch (before menus are populated).
    static func installIfNeeded() {
        guard !installed else { return }
        installed = true

        let sel = #selector(getter: NSMenuItem.image)
        guard let method = class_getInstanceMethod(NSMenuItem.self, sel) else { return }
        originalImageIMP = method_getImplementation(method)
        guard let originalIMP = originalImageIMP else { return }

        typealias OriginalGetter = @convention(c) (NSMenuItem?, Selector) -> NSImage?
        let original = unsafeBitCast(originalIMP, to: OriginalGetter.self)

        let block: @convention(block) (NSMenuItem?) -> NSImage? = { item in
            guard let item else { return nil }
            let explicit = (objc_getAssociatedObject(item, explicitImagePointer) as? NSNumber)?.boolValue == true
            if explicit {
                return original(item, sel)
            }
            return nil
        }
        let newIMP = imp_implementationWithBlock(block)
        method_setImplementation(method, newIMP)
    }

    /// Use for every status-menu row: pass `nil` to hide automatic icons; pass non-`nil` only
    /// for rows that should keep a leading image (app icon, image thumbnail).
    static func setExplicitMenuImage(_ item: NSMenuItem, image: NSImage?) {
        if image != nil {
            objc_setAssociatedObject(
                item,
                explicitImagePointer,
                NSNumber(value: true),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        } else {
            objc_setAssociatedObject(item, explicitImagePointer, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        item.image = image
    }
}
