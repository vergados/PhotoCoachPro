//
//  ToneCurveView.swift
//  PhotoCoachPro
//
//  Interactive tone curve editor
//

import SwiftUI

/// Represents a point on the tone curve
struct ToneCurvePoint: Identifiable, Equatable {
    let id: UUID
    var x: Double // Input (0-1)
    var y: Double // Output (0-1)

    init(id: UUID = UUID(), x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
}

struct ToneCurveView: View {
    @Binding var curvePoints: [ToneCurvePoint]
    let onChanged: () -> Void

    @State private var draggedPointID: UUID?

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Tone Curve")
                    .font(.headline)

                Spacer()

                Button("Reset") {
                    resetCurve()
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }

            // Curve canvas
            GeometryReader { geometry in
                ZStack {
                    // Grid background
                    gridBackground(size: geometry.size)

                    // Diagonal baseline
                    diagonalLine(size: geometry.size)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                    // Curve path
                    curvePath(size: geometry.size)
                        .stroke(Color.accentColor, lineWidth: 2)

                    // Control points
                    ForEach(curvePoints) { point in
                        controlPoint(
                            point: point,
                            size: geometry.size
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    updatePoint(point.id, to: value.location, in: geometry.size)
                                }
                                .onEnded { _ in
                                    draggedPointID = nil
                                    onChanged()
                                }
                        )
                    }
                }
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .frame(height: 250)
            .accessibilityLabel("Tone curve editor")

            // Curve presets
            HStack(spacing: 12) {
                presetButton("Linear", points: ToneCurvePoint.linear)
                presetButton("S-Curve", points: ToneCurvePoint.sCurve)
            }
        }
        .padding()
    }

    // MARK: - Subviews

    private func gridBackground(size: CGSize) -> some View {
        Canvas { context, size in
            let gridLines = 4
            let step = size.width / CGFloat(gridLines)

            for i in 0...gridLines {
                let x = CGFloat(i) * step
                let y = CGFloat(i) * step

                // Vertical lines
                var vPath = Path()
                vPath.move(to: CGPoint(x: x, y: 0))
                vPath.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(vPath, with: .color(.gray.opacity(0.1)), lineWidth: 1)

                // Horizontal lines
                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: y))
                hPath.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(hPath, with: .color(.gray.opacity(0.1)), lineWidth: 1)
            }
        }
    }

    private func diagonalLine(size: CGSize) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        return path
    }

    private func curvePath(size: CGSize) -> Path {
        var path = Path()

        let sortedPoints = curvePoints.sorted { $0.x < $1.x }

        guard let first = sortedPoints.first else { return path }

        let startPoint = toCanvasPoint(first, size: size)
        path.move(to: startPoint)

        // Use quadratic curves between points
        for i in 1..<sortedPoints.count {
            let point = toCanvasPoint(sortedPoints[i], size: size)
            let prevPoint = toCanvasPoint(sortedPoints[i - 1], size: size)

            let controlPoint = CGPoint(
                x: (prevPoint.x + point.x) / 2,
                y: (prevPoint.y + point.y) / 2
            )

            path.addQuadCurve(to: point, control: controlPoint)
        }

        return path
    }

    private func controlPoint(point: ToneCurvePoint, size: CGSize) -> some View {
        let canvasPoint = toCanvasPoint(point, size: size)

        return Circle()
            .fill(Color.accentColor)
            .frame(width: 12, height: 12)
            .position(canvasPoint)
            .accessibilityLabel("Control point at \(Int(point.x * 100))% input, \(Int(point.y * 100))% output")
    }

    private func presetButton(_ title: String, points: [ToneCurvePoint]) -> some View {
        Button(title) {
            curvePoints = points
            onChanged()
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }

    // MARK: - Helpers

    private func toCanvasPoint(_ point: ToneCurvePoint, size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * size.width,
            y: (1.0 - point.y) * size.height  // Flip Y (canvas Y goes down)
        )
    }

    private func fromCanvasPoint(_ canvasPoint: CGPoint, size: CGSize) -> ToneCurvePoint {
        ToneCurvePoint(
            x: max(0, min(1, canvasPoint.x / size.width)),
            y: max(0, min(1, 1.0 - (canvasPoint.y / size.height)))
        )
    }

    private func updatePoint(_ id: UUID, to location: CGPoint, in size: CGSize) {
        guard let index = curvePoints.firstIndex(where: { $0.id == id }) else { return }

        let tempPoint = fromCanvasPoint(location, size: size)

        // Create new point with existing id and clamped values
        let newPoint = ToneCurvePoint(
            id: id,
            x: max(0, min(1, tempPoint.x)),
            y: max(0, min(1, tempPoint.y))
        )

        curvePoints[index] = newPoint
    }

    private func resetCurve() {
        curvePoints = ToneCurvePoint.linear
        onChanged()
    }
}

extension ToneCurvePoint {
    static var linear: [ToneCurvePoint] {
        [
            ToneCurvePoint(x: 0.0, y: 0.0),
            ToneCurvePoint(x: 1.0, y: 1.0)
        ]
    }

    static var sCurve: [ToneCurvePoint] {
        [
            ToneCurvePoint(x: 0.0, y: 0.0),
            ToneCurvePoint(x: 0.25, y: 0.20),
            ToneCurvePoint(x: 0.75, y: 0.80),
            ToneCurvePoint(x: 1.0, y: 1.0)
        ]
    }
}
