import AppKit

let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
        (transform as NSAffineTransform).concat()
        let tile = NSBezierPath(roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900),
                                xRadius: 210, yRadius: 210)
        let gradient = NSGradient(starting: NSColor(srgbRed: 0.60, green: 0.48, blue: 0.98, alpha: 1),
                                  ending: NSColor(srgbRed: 0.36, green: 0.28, blue: 0.72, alpha: 1))!
        gradient.draw(in: tile, angle: -90)
        let die = NSBezierPath(roundedRect: NSRect(x: 248, y: 248, width: 528, height: 528),
                               xRadius: 110, yRadius: 110)
        NSColor.white.setFill()
        die.fill()
        NSColor(srgbRed: 0.47, green: 0.37, blue: 0.84, alpha: 1).setFill()
        for (x, y) in [(376, 376), (648, 376), (512, 512), (376, 648), (648, 648)] {
            NSBezierPath(ovalIn: NSRect(x: x - 42, y: y - 42, width: 84, height: 84)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let data = bitmap.representation(using: .png, properties: [:])!
        try data.write(to: URL(fileURLWithPath: "\(output)/icon_\(size)x\(size)\(suffix).png"))
    }
}
