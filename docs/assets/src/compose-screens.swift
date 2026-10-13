import AppKit
// The README's screenshot figures: real window captures on the plain dark backdrop, soft shadows,
// and the menu-bar circle drawn above the menu and the panel (as it looks while they are open).
let dir = CommandLine.arguments[1], out = CommandLine.arguments[2]
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func load(_ n: String) -> CGImage { let i = NSImage(contentsOfFile: "\(dir)/\(n).png")!.cgImage(forProposedRect: nil, context: nil, hints: nil)!; return i.copy(colorSpace: cs) ?? i }  // the captured values as they are (no profile conversion), like the earlier figures
func compose(_ name: String, _ w: Int, _ h: Int, _ draw: (CGContext) -> Void) {
  let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.saveGState(); ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerWidth: 40, cornerHeight: 40, transform: nil)); ctx.clip()
  let g = CGGradient(colorsSpace: cs, colors: [CGColor(srgbRed: 58/255, green: 62/255, blue: 70/255, alpha: 1), CGColor(srgbRed: 33/255, green: 35/255, blue: 41/255, alpha: 1)] as CFArray, locations: [0, 1])!
  ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: []); draw(ctx); ctx.restoreGState()
  let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!); try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name).png")); print(name, w, "x", h)
}
func place(_ c: CGContext, _ img: CGImage, x: Int, top: Int, H: Int) {
  c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -18), blur: 60, color: CGColor(gray: 0, alpha: 0.55))
  c.draw(img, in: CGRect(x: x, y: H - top - img.height, width: img.width, height: img.height)); c.restoreGState()
}
func circle(_ c: CGContext, cx: Int, top: Int, H: Int) {
  let w = 72.0, h = 46.0, r = CGRect(x: Double(cx) - w / 2, y: Double(H - top) - h, width: w, height: h)
  c.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.12)); c.addPath(CGPath(roundedRect: r, cornerWidth: 14, cornerHeight: 14, transform: nil)); c.fillPath()
  let m = CGPoint(x: r.midX, y: r.midY), R = 15.0
  c.setFillColor(CGColor(srgbRed: 0.84, green: 0.50, blue: 0.27, alpha: 1)); c.move(to: m); c.addArc(center: m, radius: R, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false); c.closePath(); c.fillPath()  // warmth: the right half
  c.setFillColor(CGColor(gray: 1, alpha: 1)); c.move(to: m); c.addArc(center: m, radius: R, startAngle: .pi / 2, endAngle: 3 * .pi / 2, clockwise: false); c.closePath(); c.fillPath()  // grayscale: the left half
  c.setStrokeColor(CGColor(gray: 1, alpha: 1)); c.setLineWidth(3); c.addEllipse(in: CGRect(x: m.x - R, y: m.y - R, width: 2 * R, height: 2 * R)); c.strokePath()
}
let menu = load("menu"), panel = load("panel"), general = load("general")
// 1 the menu and the exception panel it opens (the circle where it sits: over the menu's left, centered over the panel)
do { let W = 96 + menu.width + 96 + panel.width + 96, H = 154 + menu.height + 96, px = 96 + menu.width + 96
  compose("exceptions", W, H) { c in circle(c, cx: 140, top: 96, H: H); place(c, menu, x: 96, top: 154, H: H); circle(c, cx: px + panel.width / 2, top: 96, H: H); place(c, panel, x: px, top: 154, H: H) } }
// 2 the menu beside the Settings window on General
do { let W = 96 + menu.width + 112 + general.width + 96, H = 152 + general.height + 96
  compose("interfaces", W, H) { c in circle(c, cx: 140, top: 96, H: H); place(c, menu, x: 96, top: 154, H: H); place(c, general, x: 96 + menu.width + 112, top: 152, H: H) } }
// 3 the other five tabs
do { let sc = load("shortcuts"), se = load("sessions"), ap = load("apps"), we = load("websites"), ab = load("about")
  let r1 = max(sc.height, se.height), r2 = max(ap.height, we.height), W = 80 + 1000 + 80 + 1000 + 80, t2 = 80 + r1 + 80, t3 = t2 + r2 + 80, H = t3 + ab.height + 80
  compose("settings-tabs", W, H) { c in place(c, sc, x: 80, top: 80, H: H); place(c, se, x: 1160, top: 80, H: H); place(c, ap, x: 80, top: t2, H: H); place(c, we, x: 1160, top: t2, H: H); place(c, ab, x: (W - ab.width) / 2, top: t3, H: H) } }
