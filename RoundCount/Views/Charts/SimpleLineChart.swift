//
//  SimpleLineChart.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/18/26.
//

import SwiftUI

struct SimpleLineChart: View {
    let points: [ChartPoint]

    var body: some View {
        GeometryReader { geo in

            let ys = points.map(\.y)
            let minY = ys.min() ?? 0
            let maxY = ys.max() ?? 1
            let spanY = max(1e-9, maxY - minY)

            Canvas { ctx, size in
                guard points.count >= 2 else { return }

                func px(_ i: Int) -> CGFloat {
                    let t = CGFloat(i) / CGFloat(max(1, points.count - 1))
                    return t * size.width
                }

                func py(_ y: Double) -> CGFloat {
                    let t = (y - minY) / spanY
                    return size.height - CGFloat(t) * size.height
                }

                // grid (very subtle)
                var grid = Path()
                let rows = 3
                for r in 0...rows {
                    let y = CGFloat(r) / CGFloat(rows) * size.height
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(grid, with: .color(.secondary.opacity(0.15)), lineWidth: 1)

                // line
                var p = Path()
                p.move(to: CGPoint(x: px(0), y: py(points[0].y)))
                for i in 1..<points.count {
                    p.addLine(to: CGPoint(x: px(i), y: py(points[i].y)))
                }
                ctx.stroke(p, with: .color(.primary), lineWidth: 2)

                // last dot
                if let last = points.last {
                    let dot = CGRect(x: size.width - 4, y: py(last.y) - 4, width: 8, height: 8)
                    ctx.fill(Path(ellipseIn: dot), with: .color(.primary))
                }
            }
        }
    }
}
