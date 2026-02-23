//
//  QuickMetricsView.swift
//  PhotoCoachPro
//
//  Quick metrics display (lightweight analysis results)
//

import SwiftUI

struct QuickMetricsView: View {
    let result: QuickMetricsResult

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall Score
                overallScoreCard

                // Color Metrics
                metricCard(
                    title: "Color Analysis",
                    score: result.color.score,
                    icon: "paintpalette.fill",
                    color: .blue,
                    content: {
                        colorMetricsContent
                    }
                )

                // Sharpness Metrics
                metricCard(
                    title: "Sharpness Analysis",
                    score: result.sharpness.score,
                    icon: "sparkles",
                    color: .purple,
                    content: {
                        sharpnessMetricsContent
                    }
                )

                // Exposure Metrics
                metricCard(
                    title: "Exposure Analysis",
                    score: result.exposure.score,
                    icon: "sun.max.fill",
                    color: .orange,
                    content: {
                        exposureMetricsContent
                    }
                )
            }
            .padding()
        }
        .navigationTitle("Quick Analysis")
    }

    // MARK: - Overall Score Card

    private var overallScoreCard: some View {
        VStack(spacing: 12) {
            Text("Overall Score")
                .font(.headline)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: result.overallScore / 100.0)
                    .stroke(scoreColor(result.overallScore), lineWidth: 12)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(Int(result.overallScore))")
                        .font(.system(size: 36, weight: .bold))

                    Text("out of 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(overallInterpretation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var overallInterpretation: String {
        let score = result.overallScore
        if score >= 80 {
            return "Excellent technical quality"
        } else if score >= 65 {
            return "Good technical quality"
        } else if score >= 50 {
            return "Acceptable quality with room for improvement"
        } else {
            return "Needs improvement in multiple areas"
        }
    }

    // MARK: - Color Metrics Content

    private var colorMetricsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            metricRow("Saturation", value: String(format: "%.1f%%", result.color.saturationMean * 100))
            metricRow("Warmth", value: String(format: "%.1f", result.color.warmth))
            metricRow("Green/Magenta", value: String(format: "%.1f", result.color.greenMagenta))

            Divider()

            Text("Analysis Notes:")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(result.color.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Sharpness Metrics Content

    private var sharpnessMetricsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            metricRow("Edge Energy (Variance)", value: String(format: "%.1f", result.sharpness.laplacianVariance))
            metricRow("Edge Strength (StdDev)", value: String(format: "%.1f", result.sharpness.laplacianStdDev))

            Divider()

            Text("Analysis Notes:")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(result.sharpness.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Exposure Metrics Content

    private var exposureMetricsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            metricRow("Mean Brightness", value: String(format: "%.0f", result.exposure.brightnessMean))
            metricRow("Dynamic Range", value: String(format: "%.0f", result.exposure.dynamicRange))
            metricRow("Shadow Clipping", value: String(format: "%.1f%%", result.exposure.clippedShadows))
            metricRow("Highlight Clipping", value: String(format: "%.1f%%", result.exposure.clippedHighlights))

            Divider()

            Text("Analysis Notes:")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(result.exposure.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func metricCard<Content: View>(
        title: String,
        score: CGFloat,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)

                Text(title)
                    .font(.headline)

                Spacer()

                scoreBadge(score)
            }

            content()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func metricRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }

    private func scoreBadge(_ score: CGFloat) -> some View {
        Text("\(Int(score))")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(scoreColor(score))
            .clipShape(Circle())
    }

    private func scoreColor(_ score: CGFloat) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 65 {
            return .blue
        } else if score >= 50 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
struct QuickMetricsView_Previews: PreviewProvider {
    static var previews: some View {
        QuickMetricsView(result: QuickMetricsResult(
            color: QuickColorMetrics(
                meanRGB: [128, 132, 120],
                saturationMean: 0.35,
                saturationP95: 0.65,
                warmth: 8.0,
                greenMagenta: 4.0,
                score: 78.0,
                notes: [
                    "Saturation looks natural/healthy",
                    "White balance looks fairly neutral"
                ]
            ),
            sharpness: QuickSharpnessMetrics(
                laplacianStdDev: 15.2,
                laplacianVariance: 231.0,
                score: 82.0,
                notes: [
                    "Strong fine detail; image appears very sharp"
                ]
            ),
            exposure: QuickExposureMetrics(
                brightnessMean: 128.0,
                brightnessP05: 12.0,
                brightnessP95: 240.0,
                dynamicRange: 228.0,
                clippedShadows: 0.5,
                clippedHighlights: 1.2,
                score: 85.0,
                notes: [
                    "Overall brightness looks reasonable",
                    "Dynamic range looks healthy"
                ]
            ),
            overallScore: 81.7
        ))
        .frame(width: 400, height: 800)
    }
}
#endif
