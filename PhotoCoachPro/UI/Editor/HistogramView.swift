//
//  HistogramView.swift
//  PhotoCoachPro
//
//  Live histogram computed from the rendered CIImage using CIAreaHistogram
//

import SwiftUI
import CoreImage

struct HistogramView: View {
    @EnvironmentObject var appState: AppState

    private struct HistogramChannels {
        var red: [Float]
        var green: [Float]
        var blue: [Float]
        var binCount: Int { red.count }

        static let empty = HistogramChannels(
            red: [Float](repeating: 0, count: 256),
            green: [Float](repeating: 0, count: 256),
            blue: [Float](repeating: 0, count: 256)
        )
    }

    @State private var channels = HistogramChannels.empty

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("Histogram")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Canvas { ctx, size in
                    drawChannels(context: ctx, size: size)
                }
                .frame(height: 60)
            }
            .padding(8)
        }
        .frame(height: 100)
        .task(id: appState.renderCount) {
            await recompute()
        }
        .accessibilityLabel("Histogram")
        .accessibilityHint("Shows image tone distribution across red, green, and blue channels")
    }

    // MARK: - Drawing

    private func drawChannels(context ctx: GraphicsContext, size: CGSize) {
        let binCount = channels.binCount
        guard binCount > 1 else { return }

        let globalMax = max(
            channels.red.max() ?? 0,
            channels.green.max() ?? 0,
            channels.blue.max() ?? 0,
            Float.leastNormalMagnitude
        )

        let channelPairs: [(values: [Float], color: Color)] = [
            (channels.blue, .blue),
            (channels.green, .green),
            (channels.red, .red)
        ]

        for pair in channelPairs {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            for i in 0..<binCount {
                let x = CGFloat(i) / CGFloat(binCount - 1) * size.width
                let normalizedHeight = CGFloat(pair.values[i]) / CGFloat(globalMax)
                let y = size.height - normalizedHeight * size.height
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
            ctx.fill(path, with: .color(pair.color.opacity(0.45)))
        }
    }

    // MARK: - Computation

    private func recompute() async {
        guard let image = appState.renderedCIImage else {
            channels = .empty
            return
        }
        channels = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: HistogramView.computeChannels(from: image))
            }
        }
    }

    private static func computeChannels(from image: CIImage) -> HistogramChannels {
        let binCount = 256
        let context = CIContext(options: [.useSoftwareRenderer: false])

        guard let filter = CIFilter(name: "CIAreaHistogram") else { return .empty }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: "inputExtent")
        filter.setValue(binCount, forKey: "inputCount")
        filter.setValue(1.0, forKey: "inputScale")

        guard let output = filter.outputImage else { return .empty }

        var data = [Float](repeating: 0, count: binCount * 4)
        let rowBytes = binCount * 4 * MemoryLayout<Float>.size
        data.withUnsafeMutableBytes { ptr in
            context.render(
                output,
                toBitmap: ptr.baseAddress!,
                rowBytes: rowBytes,
                bounds: output.extent,
                format: .RGBAf,
                colorSpace: nil
            )
        }

        var red = [Float](repeating: 0, count: binCount)
        var green = [Float](repeating: 0, count: binCount)
        var blue = [Float](repeating: 0, count: binCount)
        for i in 0..<binCount {
            red[i] = max(0, data[i * 4])
            green[i] = max(0, data[i * 4 + 1])
            blue[i] = max(0, data[i * 4 + 2])
        }

        return HistogramChannels(red: red, green: green, blue: blue)
    }
}
