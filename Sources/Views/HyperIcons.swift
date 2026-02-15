import SwiftUI

// MARK: - Custom Icon Set
// Hand-drawn icons using SwiftUI Canvas/Path. All icons render into a square
// canvas and scale to the requested size. Stroke weight and corner radius
// adapt proportionally so they look sharp at any point size.

enum HyperIcon {
    case setup        // wrench: two strokes forming an angled wrench
    case registry     // cube: isometric box
    case sync         // two curved arrows forming a cycle
    case destinations // folder with arrow
    case check        // heartbeat / pulse line
    case refresh      // single curved arrow
    case settings     // sliders
    case logs         // stacked lines
    case clock        // clock face
    case quit         // power symbol
    case warning      // triangle with !
    case passed       // circled check
    case failed       // circled x
}

struct HyperIconView: View {
    let icon: HyperIcon
    let size: CGFloat
    var color: Color = .secondary

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let lw = max(1.2, s * 0.09)

            switch icon {
            case .setup:
                drawSetup(ctx: ctx, s: s, lw: lw)
            case .registry:
                drawRegistry(ctx: ctx, s: s, lw: lw)
            case .sync:
                drawSync(ctx: ctx, s: s, lw: lw)
            case .destinations:
                drawDestinations(ctx: ctx, s: s, lw: lw)
            case .check:
                drawCheck(ctx: ctx, s: s, lw: lw)
            case .refresh:
                drawRefresh(ctx: ctx, s: s, lw: lw)
            case .settings:
                drawSettings(ctx: ctx, s: s, lw: lw)
            case .logs:
                drawLogs(ctx: ctx, s: s, lw: lw)
            case .clock:
                drawClock(ctx: ctx, s: s, lw: lw)
            case .quit:
                drawQuit(ctx: ctx, s: s, lw: lw)
            case .warning:
                drawWarning(ctx: ctx, s: s, lw: lw)
            case .passed:
                drawPassed(ctx: ctx, s: s, lw: lw)
            case .failed:
                drawFailed(ctx: ctx, s: s, lw: lw)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Wrench (Setup)
    private func drawSetup(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        // Wrench shape: angled handle + jaw
        var path = Path()
        // Handle
        path.move(to: CGPoint(x: s * 0.22, y: s * 0.78))
        path.addLine(to: CGPoint(x: s * 0.55, y: s * 0.45))
        // Jaw (open end)
        path.move(to: CGPoint(x: s * 0.55, y: s * 0.45))
        path.addLine(to: CGPoint(x: s * 0.50, y: s * 0.25))
        path.addCurve(
            to: CGPoint(x: s * 0.78, y: s * 0.22),
            control1: CGPoint(x: s * 0.55, y: s * 0.12),
            control2: CGPoint(x: s * 0.72, y: s * 0.12)
        )
        path.addLine(to: CGPoint(x: s * 0.55, y: s * 0.45))
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Cube (Registry)
    private func drawRegistry(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        let cx = s * 0.5, top = s * 0.12, bot = s * 0.88
        let midY = s * 0.5
        let dx = s * 0.38
        var path = Path()
        // Top diamond
        path.move(to: CGPoint(x: cx, y: top))
        path.addLine(to: CGPoint(x: cx + dx, y: top + (midY - top) * 0.5))
        path.addLine(to: CGPoint(x: cx, y: midY))
        path.addLine(to: CGPoint(x: cx - dx, y: top + (midY - top) * 0.5))
        path.closeSubpath()
        // Left face
        path.move(to: CGPoint(x: cx - dx, y: top + (midY - top) * 0.5))
        path.addLine(to: CGPoint(x: cx - dx, y: bot - (midY - top) * 0.5))
        path.addLine(to: CGPoint(x: cx, y: bot))
        path.addLine(to: CGPoint(x: cx, y: midY))
        // Right face
        path.move(to: CGPoint(x: cx + dx, y: top + (midY - top) * 0.5))
        path.addLine(to: CGPoint(x: cx + dx, y: bot - (midY - top) * 0.5))
        path.addLine(to: CGPoint(x: cx, y: bot))
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Sync (two circular arrows)
    private func drawSync(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        let center = CGPoint(x: s * 0.5, y: s * 0.5)
        let r = s * 0.32

        // Top arc (clockwise, ~270 degrees)
        var arc1 = Path()
        arc1.addArc(center: center, radius: r, startAngle: .degrees(-90), endAngle: .degrees(150), clockwise: false)
        ctx.stroke(arc1, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))

        // Arrow head at the end of arc1 (~150 degrees)
        let a1End = CGPoint(x: center.x + r * cos(.pi * 150 / 180), y: center.y + r * sin(.pi * 150 / 180))
        var arr1 = Path()
        arr1.move(to: CGPoint(x: a1End.x + s * 0.08, y: a1End.y - s * 0.06))
        arr1.addLine(to: a1End)
        arr1.addLine(to: CGPoint(x: a1End.x + s * 0.10, y: a1End.y + s * 0.04))
        ctx.stroke(arr1, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

        // Bottom arc
        var arc2 = Path()
        arc2.addArc(center: center, radius: r, startAngle: .degrees(90), endAngle: .degrees(-30), clockwise: false)
        ctx.stroke(arc2, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))

        let a2End = CGPoint(x: center.x + r * cos(.pi * -30 / 180), y: center.y + r * sin(.pi * -30 / 180))
        var arr2 = Path()
        arr2.move(to: CGPoint(x: a2End.x - s * 0.08, y: a2End.y + s * 0.06))
        arr2.addLine(to: a2End)
        arr2.addLine(to: CGPoint(x: a2End.x - s * 0.10, y: a2End.y - s * 0.04))
        ctx.stroke(arr2, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Folder (Destinations)
    private func drawDestinations(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        var path = Path()
        // Folder outline
        let l = s * 0.12, r = s * 0.88
        let t = s * 0.22, b = s * 0.82
        let tab = s * 0.38, tabT = s * 0.14
        path.move(to: CGPoint(x: l, y: t))
        path.addLine(to: CGPoint(x: l, y: b))
        path.addLine(to: CGPoint(x: r, y: b))
        path.addLine(to: CGPoint(x: r, y: t))
        path.addLine(to: CGPoint(x: tab + s * 0.06, y: t))
        path.addLine(to: CGPoint(x: tab, y: tabT))
        path.addLine(to: CGPoint(x: l, y: tabT))
        path.closeSubpath()
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

        // Arrow pointing down into folder
        var arrow = Path()
        arrow.move(to: CGPoint(x: s * 0.5, y: s * 0.40))
        arrow.addLine(to: CGPoint(x: s * 0.5, y: s * 0.68))
        arrow.move(to: CGPoint(x: s * 0.38, y: s * 0.58))
        arrow.addLine(to: CGPoint(x: s * 0.5, y: s * 0.68))
        arrow.addLine(to: CGPoint(x: s * 0.62, y: s * 0.58))
        ctx.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Pulse (Check / Diagnostics)
    private func drawCheck(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: s * 0.08, y: s * 0.5))
        path.addLine(to: CGPoint(x: s * 0.28, y: s * 0.5))
        path.addLine(to: CGPoint(x: s * 0.38, y: s * 0.22))
        path.addLine(to: CGPoint(x: s * 0.50, y: s * 0.72))
        path.addLine(to: CGPoint(x: s * 0.60, y: s * 0.38))
        path.addLine(to: CGPoint(x: s * 0.68, y: s * 0.5))
        path.addLine(to: CGPoint(x: s * 0.92, y: s * 0.5))
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Refresh (single arrow)
    private func drawRefresh(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        let center = CGPoint(x: s * 0.5, y: s * 0.5)
        let r = s * 0.32

        var arc = Path()
        arc.addArc(center: center, radius: r, startAngle: .degrees(-60), endAngle: .degrees(200), clockwise: false)
        ctx.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))

        // Arrow at -60 degrees (top-right)
        let tip = CGPoint(x: center.x + r * cos(.pi * -60 / 180), y: center.y + r * sin(.pi * -60 / 180))
        var arr = Path()
        arr.move(to: CGPoint(x: tip.x - s * 0.01, y: tip.y - s * 0.12))
        arr.addLine(to: tip)
        arr.addLine(to: CGPoint(x: tip.x + s * 0.11, y: tip.y + s * 0.02))
        ctx.stroke(arr, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Sliders (Settings)
    private func drawSettings(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        let positions: [(y: CGFloat, knob: CGFloat)] = [
            (s * 0.25, s * 0.35),
            (s * 0.50, s * 0.65),
            (s * 0.75, s * 0.42),
        ]
        let left = s * 0.15, right = s * 0.85
        let knobR = s * 0.06

        for (y, knob) in positions {
            var line = Path()
            line.move(to: CGPoint(x: left, y: y))
            line.addLine(to: CGPoint(x: right, y: y))
            ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: lw * 0.7, lineCap: .round))

            var circle = Path()
            circle.addEllipse(in: CGRect(x: knob - knobR, y: y - knobR, width: knobR * 2, height: knobR * 2))
            ctx.fill(circle, with: .color(color))
        }
    }

    // MARK: - Logs (stacked lines)
    private func drawLogs(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        let left = s * 0.18, right = s * 0.82
        let ys = [s * 0.28, s * 0.42, s * 0.56, s * 0.70]
        let widths = [0.9, 0.7, 0.85, 0.6]

        for (y, w) in zip(ys, widths) {
            var line = Path()
            line.move(to: CGPoint(x: left, y: y))
            line.addLine(to: CGPoint(x: left + (right - left) * w, y: y))
            ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
        }
    }

    // MARK: - Clock
    private func drawClock(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        let center = CGPoint(x: s * 0.5, y: s * 0.5)
        let r = s * 0.36

        var circle = Path()
        circle.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ctx.stroke(circle, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))

        // Hour hand (pointing to ~10)
        var hands = Path()
        hands.move(to: center)
        hands.addLine(to: CGPoint(x: center.x - s * 0.08, y: center.y - s * 0.18))
        // Minute hand (pointing to ~2)
        hands.move(to: center)
        hands.addLine(to: CGPoint(x: center.x + s * 0.16, y: center.y - s * 0.10))
        ctx.stroke(hands, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }

    // MARK: - Power / Quit
    private func drawQuit(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        let center = CGPoint(x: s * 0.5, y: s * 0.54)
        let r = s * 0.30

        // Open circle (gap at top)
        var arc = Path()
        arc.addArc(center: center, radius: r, startAngle: .degrees(-55), endAngle: .degrees(235), clockwise: true)
        ctx.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))

        // Vertical stem
        var stem = Path()
        stem.move(to: CGPoint(x: s * 0.5, y: s * 0.16))
        stem.addLine(to: CGPoint(x: s * 0.5, y: s * 0.48))
        ctx.stroke(stem, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }

    // MARK: - Warning triangle
    private func drawWarning(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        var tri = Path()
        tri.move(to: CGPoint(x: s * 0.5, y: s * 0.12))
        tri.addLine(to: CGPoint(x: s * 0.88, y: s * 0.82))
        tri.addLine(to: CGPoint(x: s * 0.12, y: s * 0.82))
        tri.closeSubpath()
        ctx.stroke(tri, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

        // Exclamation
        var excl = Path()
        excl.move(to: CGPoint(x: s * 0.5, y: s * 0.38))
        excl.addLine(to: CGPoint(x: s * 0.5, y: s * 0.58))
        ctx.stroke(excl, with: .color(color), style: StrokeStyle(lineWidth: lw * 1.2, lineCap: .round))
        // Dot
        var dot = Path()
        dot.addEllipse(in: CGRect(x: s * 0.5 - lw * 0.7, y: s * 0.68 - lw * 0.7, width: lw * 1.4, height: lw * 1.4))
        ctx.fill(dot, with: .color(color))
    }

    // MARK: - Passed (circled checkmark)
    private func drawPassed(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        let center = CGPoint(x: s * 0.5, y: s * 0.5)
        let r = s * 0.36
        var circle = Path()
        circle.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ctx.stroke(circle, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))

        var check = Path()
        check.move(to: CGPoint(x: s * 0.30, y: s * 0.50))
        check.addLine(to: CGPoint(x: s * 0.45, y: s * 0.64))
        check.addLine(to: CGPoint(x: s * 0.70, y: s * 0.36))
        ctx.stroke(check, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Failed (circled X)
    private func drawFailed(ctx: GraphicsContext, s: CGFloat, lw: CGFloat) {
        let center = CGPoint(x: s * 0.5, y: s * 0.5)
        let r = s * 0.36
        var circle = Path()
        circle.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ctx.stroke(circle, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))

        let d = s * 0.18
        var x = Path()
        x.move(to: CGPoint(x: center.x - d, y: center.y - d))
        x.addLine(to: CGPoint(x: center.x + d, y: center.y + d))
        x.move(to: CGPoint(x: center.x + d, y: center.y - d))
        x.addLine(to: CGPoint(x: center.x - d, y: center.y + d))
        ctx.stroke(x, with: .color(color), style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }
}
