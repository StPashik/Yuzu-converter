import AppKit

/// Shelf and operation windows share the same material and accessibility fallback.
@MainActor
enum AppSurface {
    static func make(content: NSView, opaque: Bool, cornerRadius: CGFloat = 24) -> NSView {
        content.removeFromSuperview()
        let surface: NSView
        if opaque {
            let box = NSBox()
            box.boxType = .custom
            box.titlePosition = .noTitle
            box.cornerRadius = cornerRadius
            box.fillColor = .windowBackgroundColor
            box.borderColor = .separatorColor
            box.contentViewMargins = .zero
            box.contentView = content
            surface = box
        } else {
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                let glass = NSGlassEffectView()
                glass.style = .regular
                glass.cornerRadius = cornerRadius
                // AppKit guarantees glass ordering through contentView, rather than arbitrary subviews.
                glass.contentView = content
                surface = glass
            } else { surface = fallback(content: content, cornerRadius: cornerRadius) }
            #else
            surface = fallback(content: content, cornerRadius: cornerRadius)
            #endif
        }
        // Clip every backing layer, including the glass rim, to the same transparent window corners.
        surface.wantsLayer = true
        surface.layer?.cornerRadius = cornerRadius
        surface.layer?.masksToBounds = true
        content.autoresizingMask = [.width, .height]
        return surface
    }

    private static func fallback(content: NSView, cornerRadius: CGFloat) -> NSView {
        let material = NSVisualEffectView()
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.cornerRadius = cornerRadius
        material.layer?.masksToBounds = true
        material.addSubview(content)
        return material
    }
}
