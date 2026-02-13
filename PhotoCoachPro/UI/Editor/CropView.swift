//
//  CropView.swift
//  PhotoCoachPro
//
//  Crop, straighten, and geometry tools
//

import SwiftUI

struct CropView: View {
    @Binding var cropRect: CGRect
    @Binding var rotationAngle: Double
    @Binding var aspectRatio: CropAspectRatio?

    let imageSize: CGSize
    let onChanged: () -> Void

    @State private var activeHandle: HandlePosition?
    @State private var showGrid = true

    enum HandlePosition {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    var body: some View {
        VStack(spacing: 16) {
            // Aspect ratio selector
            aspectRatioSelector

            // Crop canvas
            GeometryReader { geometry in
                ZStack {
                    // Image preview area
                    Color.black.opacity(0.5)

                    // Crop rectangle
                    cropOverlay(in: geometry.size)
                }
            }
            .frame(maxHeight: 400)
            .background(Color.black)

            // Rotation slider
            rotationSlider

            // Action buttons
            actionButtons
        }
    }

    // MARK: - Subviews

    private var aspectRatioSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                aspectRatioButton(.free)
                aspectRatioButton(.original)
                aspectRatioButton(.square)
                aspectRatioButton(.ratio3x2)
                aspectRatioButton(.ratio4x3)
                aspectRatioButton(.ratio16x9)
                aspectRatioButton(.ratio9x16)
            }
            .padding(.horizontal)
        }
    }

    private func aspectRatioButton(_ ratio: CropAspectRatio) -> some View {
        Button {
            aspectRatio = ratio
            applyAspectRatio(ratio)
        } label: {
            VStack(spacing: 4) {
                ratio.icon
                    .font(.title3)

                Text(ratio.name)
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(aspectRatio == ratio ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(aspectRatio == ratio ? .primary : .secondary)
    }

    private func cropOverlay(in size: CGSize) -> some View {
        GeometryReader { geo in
            ZStack {
                // Darkened outside area
                outsideMask(in: size)

                // Crop rectangle with handles
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(cropRect.center)

                // Grid (rule of thirds)
                if showGrid {
                    gridLines(in: cropRect)
                }

                // Corner handles
                cornerHandle(.topLeft)
                cornerHandle(.topRight)
                cornerHandle(.bottomLeft)
                cornerHandle(.bottomRight)

                // Edge handles
                edgeHandle(.top)
                edgeHandle(.bottom)
                edgeHandle(.left)
                edgeHandle(.right)
            }
        }
    }

    private func outsideMask(in size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.7)

            Rectangle()
                .fill(Color.clear)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(cropRect.center)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    private func gridLines(in rect: CGRect) -> some View {
        Canvas { context, _ in
            let path = Path { p in
                // Vertical lines (thirds)
                let x1 = rect.minX + rect.width / 3
                let x2 = rect.minX + (rect.width * 2) / 3

                p.move(to: CGPoint(x: x1, y: rect.minY))
                p.addLine(to: CGPoint(x: x1, y: rect.maxY))

                p.move(to: CGPoint(x: x2, y: rect.minY))
                p.addLine(to: CGPoint(x: x2, y: rect.maxY))

                // Horizontal lines (thirds)
                let y1 = rect.minY + rect.height / 3
                let y2 = rect.minY + (rect.height * 2) / 3

                p.move(to: CGPoint(x: rect.minX, y: y1))
                p.addLine(to: CGPoint(x: rect.maxX, y: y1))

                p.move(to: CGPoint(x: rect.minX, y: y2))
                p.addLine(to: CGPoint(x: rect.maxX, y: y2))
            }

            context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 1)
        }
    }

    private func cornerHandle(_ position: HandlePosition) -> some View {
        let point = handlePoint(for: position)

        return Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .position(point)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        updateCropRect(for: position, translation: value.translation)
                    }
                    .onEnded { _ in
                        activeHandle = nil
                        onChanged()
                    }
            )
    }

    private func edgeHandle(_ position: HandlePosition) -> some View {
        let point = handlePoint(for: position)

        return Rectangle()
            .fill(Color.white)
            .frame(width: position == .left || position == .right ? 6 : 40,
                   height: position == .top || position == .bottom ? 6 : 40)
            .position(point)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        updateCropRect(for: position, translation: value.translation)
                    }
                    .onEnded { _ in
                        activeHandle = nil
                        onChanged()
                    }
            )
    }

    private var rotationSlider: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "rotate.left")
                    .foregroundStyle(.secondary)

                Text("Straighten")
                    .font(.subheadline)

                Spacer()

                Text(String(format: "%.1f°", rotationAngle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Button {
                    rotationAngle = 0
                    onChanged()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                }
                .opacity(rotationAngle == 0 ? 0 : 1)
            }

            Slider(value: $rotationAngle, in: -10...10) { editing in
                if !editing {
                    onChanged()
                }
            }
        }
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                showGrid.toggle()
            } label: {
                Label(showGrid ? "Hide Grid" : "Show Grid", systemImage: "grid")
            }

            Spacer()

            Button("Reset") {
                resetCrop()
            }
            .foregroundStyle(.red)

            Button("Apply") {
                onChanged()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func handlePoint(for position: HandlePosition) -> CGPoint {
        switch position {
        case .topLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        case .top:
            return CGPoint(x: cropRect.midX, y: cropRect.minY)
        case .bottom:
            return CGPoint(x: cropRect.midX, y: cropRect.maxY)
        case .left:
            return CGPoint(x: cropRect.minX, y: cropRect.midY)
        case .right:
            return CGPoint(x: cropRect.maxX, y: cropRect.midY)
        }
    }

    private func updateCropRect(for position: HandlePosition, translation: CGSize) {
        var newRect = cropRect

        switch position {
        case .topLeft:
            newRect.origin.x += translation.width
            newRect.origin.y += translation.height
            newRect.size.width -= translation.width
            newRect.size.height -= translation.height
        case .topRight:
            newRect.origin.y += translation.height
            newRect.size.width += translation.width
            newRect.size.height -= translation.height
        case .bottomLeft:
            newRect.origin.x += translation.width
            newRect.size.width -= translation.width
            newRect.size.height += translation.height
        case .bottomRight:
            newRect.size.width += translation.width
            newRect.size.height += translation.height
        case .top:
            newRect.origin.y += translation.height
            newRect.size.height -= translation.height
        case .bottom:
            newRect.size.height += translation.height
        case .left:
            newRect.origin.x += translation.width
            newRect.size.width -= translation.width
        case .right:
            newRect.size.width += translation.width
        }

        // Enforce minimum size
        if newRect.width > 50 && newRect.height > 50 {
            cropRect = newRect
        }
    }

    private func applyAspectRatio(_ ratio: CropAspectRatio) {
        guard let targetRatio = ratio.ratio else { return }

        let currentRatio = cropRect.width / cropRect.height

        if currentRatio > targetRatio {
            // Too wide, shrink width
            let newWidth = cropRect.height * targetRatio
            cropRect = CGRect(
                x: cropRect.midX - newWidth / 2,
                y: cropRect.minY,
                width: newWidth,
                height: cropRect.height
            )
        } else {
            // Too tall, shrink height
            let newHeight = cropRect.width / targetRatio
            cropRect = CGRect(
                x: cropRect.minX,
                y: cropRect.midY - newHeight / 2,
                width: cropRect.width,
                height: newHeight
            )
        }

        onChanged()
    }

    private func resetCrop() {
        cropRect = CGRect(origin: .zero, size: imageSize)
        rotationAngle = 0
        aspectRatio = .free
        onChanged()
    }
}

// MARK: - Crop Aspect Ratio
enum CropAspectRatio: Equatable {
    case free
    case original
    case square
    case ratio3x2
    case ratio4x3
    case ratio16x9
    case ratio9x16

    var name: String {
        switch self {
        case .free: return "Free"
        case .original: return "Original"
        case .square: return "1:1"
        case .ratio3x2: return "3:2"
        case .ratio4x3: return "4:3"
        case .ratio16x9: return "16:9"
        case .ratio9x16: return "9:16"
        }
    }

    var icon: Image {
        Image(systemName: "crop")
    }

    var ratio: Double? {
        switch self {
        case .free, .original: return nil
        case .square: return 1.0
        case .ratio3x2: return 3.0 / 2.0
        case .ratio4x3: return 4.0 / 3.0
        case .ratio16x9: return 16.0 / 9.0
        case .ratio9x16: return 9.0 / 16.0
        }
    }
}

// MARK: - CGRect Extension
extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
