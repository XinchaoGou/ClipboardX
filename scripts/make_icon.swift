import AppKit

// Crops the source artwork to the squircle's bounding box, then re-rounds the
// corners with a transparent mask, producing a clean 1024x1024 macOS app icon.

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: make_icon.swift <in.png> <out.png>\n".data(using: .utf8)!)
    exit(2)
}
let inURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])

guard let src = NSImage(contentsOf: inURL),
      let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("could not load image\n".data(using: .utf8)!)
    exit(1)
}

let w = cg.width, h = cg.height
let bytesPerRow = w * 4
var pixels = [UInt8](repeating: 0, count: bytesPerRow * h)
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: bytesPerRow, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    exit(1)
}
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

// Find bounding box of non-near-black pixels (the artwork over a black bg).
var minX = w, minY = h, maxX = 0, maxY = 0
let threshold = 45
for y in 0..<h {
    for x in 0..<w {
        let i = y * bytesPerRow + x * 4
        let r = Int(pixels[i]), g = Int(pixels[i+1]), b = Int(pixels[i+2])
        let lum = (r * 299 + g * 587 + b * 114) / 1000
        if lum > threshold {
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
        }
    }
}
guard maxX > minX, maxY > minY else { exit(1) }

// Make the crop square, centred on the detected bounding box.
let bw = maxX - minX + 1, bh = maxY - minY + 1
let side = max(bw, bh)
let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
var sx = cx - side / 2, sy = cy - side / 2
sx = max(0, min(sx, w - side)); sy = max(0, min(sy, h - side))
// CoreGraphics origin is bottom-left; our scan used top-left, but a centred
// square crop is symmetric so the rect is the same either way.
let cropRect = CGRect(x: sx, y: sy, width: side, height: side)
guard let cropped = cg.cropping(to: cropRect) else { exit(1) }

// Render into a 1024 canvas with rounded (transparent) corners.
let out = 1024
guard let outCtx = CGContext(data: nil, width: out, height: out, bitsPerComponent: 8,
                             bytesPerRow: out * 4, space: cs,
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    exit(1)
}
outCtx.clear(CGRect(x: 0, y: 0, width: out, height: out))
let radius = CGFloat(out) * 0.2237   // Apple-like corner radius
let rect = CGRect(x: 0, y: 0, width: out, height: out)
let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
outCtx.addPath(path)
outCtx.clip()
outCtx.interpolationQuality = .high
outCtx.draw(cropped, in: rect)

guard let result = outCtx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: result)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: outURL)
print("wrote \(outURL.path) from crop \(Int(cropRect.width))x\(Int(cropRect.height))")
