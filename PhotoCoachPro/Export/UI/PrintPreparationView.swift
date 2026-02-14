//
//  PrintPreparationView.swift
//  PhotoCoachPro
//
//  Print preparation settings and export
//

import SwiftUI

/// Prepare photos for printing
struct PrintPreparationView: View {
    let photoRecord: PhotoRecord
    @State private var settings = ExportSettings.print
    @State private var printSize: PrintSize = .standard4x6
    @State private var dpi: Int = 300
    @State private var paperType: PaperType = .glossy
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Print size
                printSizeSection

                // DPI
                dpiSection

                // Paper type
                paperTypeSection

                // Color settings
                colorSettingsSection

                // Metadata
                metadataSection

                // Print info
                printInfoSection
            }
            .navigationTitle("Print Preparation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        exportForPrint()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showSettings) {
                ExportOptionsView(
                    settings: $settings,
                    onExport: { _ in }
                )
            }
        }
    }

    // MARK: - Print Size

    private var printSizeSection: some View {
        Section {
            Picker("Print Size", selection: $printSize) {
                ForEach(PrintSize.allCases, id: \.self) { size in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(size.rawValue)
                            .font(.body)
                        Text(size.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(size)
                }
            }
            .pickerStyle(.navigationLink)
            .onChange(of: printSize) { _, newSize in
                updateResolutionForPrintSize(newSize)
            }
        } header: {
            Text("Print Size")
        } footer: {
            Text(printSize.description)
        }
    }

    // MARK: - DPI

    private var dpiSection: some View {
        Section {
            Picker("DPI", selection: $dpi) {
                Text("150 DPI (Draft)").tag(150)
                Text("200 DPI (Good)").tag(200)
                Text("300 DPI (Standard)").tag(300)
                Text("600 DPI (High Quality)").tag(600)
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Resolution (DPI)")
        } footer: {
            Text(dpiDescription)
        }
    }

    // MARK: - Paper Type

    private var paperTypeSection: some View {
        Section {
            Picker("Paper Type", selection: $paperType) {
                ForEach(PaperType.allCases, id: \.self) { type in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(type.rawValue)
                            .font(.body)
                        Text(type.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Paper Type")
        } footer: {
            Text(paperType.description)
        }
    }

    // MARK: - Color Settings

    private var colorSettingsSection: some View {
        Section {
            HStack {
                Text("Color Space")
                Spacer()
                Text(settings.colorSpace.rawValue)
                    .foregroundColor(.secondary)
            }

            Button(action: { showSettings = true }) {
                HStack {
                    Text("Advanced Color Settings")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Color Management")
        } footer: {
            Text("Adobe RGB is recommended for professional printing")
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        Section {
            Picker("Metadata", selection: $settings.metadata) {
                ForEach(ExportSettings.MetadataOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } header: {
            Text("Metadata")
        }
    }

    // MARK: - Print Info

    private var printInfoSection: some View {
        Section {
            HStack {
                Text("Output Dimensions")
                Spacer()
                Text(printSize.dimensions)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Output Pixels")
                Spacer()
                Text(outputPixels)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Format")
                Spacer()
                Text(settings.format.rawValue)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Est. File Size")
                Spacer()
                Text(estimatedFileSize)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Output Information")
        }
    }

    // MARK: - Computed Properties

    private var dpiDescription: String {
        switch dpi {
        case 150:
            return "Draft quality, suitable for proofs"
        case 200:
            return "Good quality for everyday prints"
        case 300:
            return "Standard professional quality"
        case 600:
            return "High-end professional printing"
        default:
            return "\(dpi) DPI"
        }
    }

    private var outputPixels: String {
        let (width, height) = printSize.pixelDimensions(dpi: dpi)
        return "\(width) × \(height) px"
    }

    private var estimatedFileSize: String {
        let (width, height) = printSize.pixelDimensions(dpi: dpi)
        let megapixels = Double(width * height) / 1_000_000
        let sizeMB = Int(megapixels * 3) // Rough estimate

        if sizeMB > 100 {
            return "\(sizeMB) MB"
        } else {
            return "\(sizeMB) MB"
        }
    }

    // MARK: - Actions

    private func updateResolutionForPrintSize(_ size: PrintSize) {
        // Automatically set optimal DPI
        switch size {
        case .standard4x6, .standard5x7:
            dpi = 300
        case .standard8x10, .large11x14:
            dpi = 300
        case .poster16x20, .poster20x30, .poster24x36:
            dpi = 200 // Lower DPI for larger sizes
        case .custom:
            dpi = 300
        }
    }

    private func exportForPrint() {
        // Export with print settings
        print("Exporting for print: \(printSize.rawValue) at \(dpi) DPI")
        dismiss()
    }
}

// MARK: - Print Size

enum PrintSize: String, CaseIterable {
    case standard4x6 = "4×6\""
    case standard5x7 = "5×7\""
    case standard8x10 = "8×10\""
    case large11x14 = "11×14\""
    case poster16x20 = "16×20\""
    case poster20x30 = "20×30\""
    case poster24x36 = "24×36\""
    case custom = "Custom"

    var description: String {
        switch self {
        case .standard4x6:
            return "Standard photo print"
        case .standard5x7:
            return "Small frame size"
        case .standard8x10:
            return "Common frame size"
        case .large11x14:
            return "Large frame size"
        case .poster16x20:
            return "Small poster size"
        case .poster20x30:
            return "Medium poster size"
        case .poster24x36:
            return "Large poster size"
        case .custom:
            return "Specify custom dimensions"
        }
    }

    var dimensions: String {
        switch self {
        case .standard4x6: return "4 × 6 inches"
        case .standard5x7: return "5 × 7 inches"
        case .standard8x10: return "8 × 10 inches"
        case .large11x14: return "11 × 14 inches"
        case .poster16x20: return "16 × 20 inches"
        case .poster20x30: return "20 × 30 inches"
        case .poster24x36: return "24 × 36 inches"
        case .custom: return "Custom"
        }
    }

    func pixelDimensions(dpi: Int) -> (width: Int, height: Int) {
        switch self {
        case .standard4x6: return (4 * dpi, 6 * dpi)
        case .standard5x7: return (5 * dpi, 7 * dpi)
        case .standard8x10: return (8 * dpi, 10 * dpi)
        case .large11x14: return (11 * dpi, 14 * dpi)
        case .poster16x20: return (16 * dpi, 20 * dpi)
        case .poster20x30: return (20 * dpi, 30 * dpi)
        case .poster24x36: return (24 * dpi, 36 * dpi)
        case .custom: return (8 * dpi, 10 * dpi) // Default
        }
    }
}

// MARK: - Paper Type

enum PaperType: String, CaseIterable {
    case glossy = "Glossy"
    case matte = "Matte"
    case satin = "Satin"
    case metallic = "Metallic"
    case canvas = "Canvas"
    case fineArt = "Fine Art"

    var description: String {
        switch self {
        case .glossy:
            return "Shiny finish, vibrant colors"
        case .matte:
            return "No glare, subdued colors"
        case .satin:
            return "Semi-gloss, balanced finish"
        case .metallic:
            return "Pearl finish, enhanced highlights"
        case .canvas:
            return "Textured, gallery-wrap ready"
        case .fineArt:
            return "Museum-grade, archival quality"
        }
    }
}

// MARK: - Preview

#Preview {
    PrintPreparationView(
        photoRecord: PhotoRecord(
            filePath: "/path/to/photo.jpg",
            fileName: "landscape.jpg",
            createdDate: Date(),
            width: 6000,
            height: 4000,
            fileFormat: "JPEG",
            fileSizeBytes: 8000000
        )
    )
}
