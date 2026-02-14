//
//  BatchExportView.swift
//  PhotoCoachPro
//
//  Batch export UI with progress tracking
//

import SwiftUI

/// Batch export multiple photos
struct BatchExportView: View {
    @State private var batchJob: BatchExportJob
    @State private var isExporting = false
    @State private var showSettings = false
    @State private var currentJobIndex = 0
    @Environment(\.dismiss) private var dismiss

    let photos: [PhotoRecord]
    let onComplete: ([URL]) -> Void

    init(
        photos: [PhotoRecord],
        settings: ExportSettings = ExportSettings(),
        onComplete: @escaping ([URL]) -> Void
    ) {
        self.photos = photos
        self.onComplete = onComplete

        // Create export jobs
        let jobs = photos.map { photo in
            ExportJob(
                photoID: photo.id,
                settings: settings
            )
        }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoCoachPro_Export_\(UUID().uuidString)")

        self._batchJob = State(initialValue: BatchExportJob(
            jobs: jobs,
            settings: settings,
            outputDirectory: outputDir
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isExporting {
                    exportingView
                } else {
                    readyView
                }
            }
            .navigationTitle("Batch Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isExporting)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isExporting {
                        Button("Settings") {
                            showSettings = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                ExportOptionsView(
                    settings: $batchJob.settings,
                    onExport: { newSettings in
                        updateJobsSettings(newSettings)
                    }
                )
            }
        }
    }

    // MARK: - Ready View

    private var readyView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                VStack(spacing: 8) {
                    Text("Ready to Export")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(batchJob.totalJobs) photo(s)")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 40)

            // Settings summary
            settingsSummaryCard

            Spacer()

            // Export button
            Button(action: startExport) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Start Export")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding()
        }
    }

    // MARK: - Exporting View

    private var exportingView: some View {
        VStack(spacing: 24) {
            // Overall progress
            VStack(spacing: 12) {
                Text("Exporting...")
                    .font(.title2)
                    .fontWeight(.semibold)

                ProgressView(value: batchJob.overallProgress) {
                    HStack {
                        Text("\(batchJob.completedJobs)/\(batchJob.totalJobs)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(batchJob.overallProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 40)

            // Job list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(batchJob.jobs.enumerated()), id: \.element.id) { index, job in
                        JobRow(
                            job: job,
                            isActive: index == currentJobIndex
                        )
                    }
                }
                .padding()
            }

            Spacer()

            // Complete button (shown when done)
            if batchJob.isComplete {
                Button(action: {
                    let successfulURLs = batchJob.jobs
                        .filter { $0.status == .completed }
                        .compactMap { $0.outputURL }
                    onComplete(successfulURLs)
                    dismiss()
                }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding()
            }
        }
    }

    // MARK: - Settings Summary

    private var settingsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                SettingRow(label: "Format", value: batchJob.settings.format.rawValue)
                SettingRow(label: "Quality", value: batchJob.settings.quality.rawValue)
                SettingRow(label: "Resolution", value: batchJob.settings.resolution.rawValue)
                SettingRow(label: "Color Space", value: batchJob.settings.colorSpace.rawValue)
                SettingRow(label: "Metadata", value: batchJob.settings.metadata.rawValue)

                Divider()

                SettingRow(label: "Est. Size Each", value: batchJob.settings.estimatedFileSize)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func startExport() {
        isExporting = true

        Task {
            // Create output directory
            try? FileManager.default.createDirectory(
                at: batchJob.outputDirectory,
                withIntermediateDirectories: true
            )

            // Export each job
            for (index, var job) in batchJob.jobs.enumerated() {
                currentJobIndex = index

                // Update status to processing
                job.status = .processing
                batchJob.jobs[index] = job

                // Simulate export (replace with actual ExportEngine call)
                do {
                    // Generate output filename
                    let photo = photos[index]
                    let filename = "\(photo.fileName.replacingOccurrences(of: ".", with: "_")).\(batchJob.settings.format.fileExtension)"
                    let outputURL = batchJob.outputDirectory.appendingPathComponent(filename)

                    // Simulate progress
                    for progress in stride(from: 0.0, through: 1.0, by: 0.25) {
                        job.updateProgress(progress)
                        batchJob.jobs[index] = job
                        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                    }

                    // Mark complete
                    job.complete(url: outputURL)
                    batchJob.jobs[index] = job
                } catch {
                    job.fail(error: error.localizedDescription)
                    batchJob.jobs[index] = job
                }
            }
        }
    }

    private func updateJobsSettings(_ newSettings: ExportSettings) {
        batchJob.settings = newSettings

        // Update all job settings
        for index in batchJob.jobs.indices {
            batchJob.jobs[index].settings = newSettings
        }
    }
}

// MARK: - Job Row

private struct JobRow: View {
    let job: ExportJob
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: job.status.icon)
                .font(.title3)
                .foregroundColor(Color(job.status.color))
                .frame(width: 32)

            // Job info
            VStack(alignment: .leading, spacing: 4) {
                Text("Photo \(job.id.uuidString.prefix(8))...")
                    .font(.subheadline)
                    .fontWeight(isActive ? .semibold : .regular)

                Text(job.status.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Progress
            if job.status == .processing {
                ProgressView(value: job.progress)
                    .frame(width: 60)
            } else if job.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if job.status == .failed {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(isActive ? Color.blue.opacity(0.1) : Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Setting Row

private struct SettingRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Preview

#Preview {
    BatchExportView(
        photos: [
            PhotoRecord(
                filePath: "/path/to/photo1.jpg",
                fileName: "photo1.jpg",
                createdDate: Date(),
                width: 4000,
                height: 3000,
                fileFormat: "JPEG",
                fileSizeBytes: 5000000
            ),
            PhotoRecord(
                filePath: "/path/to/photo2.jpg",
                fileName: "photo2.jpg",
                createdDate: Date(),
                width: 4000,
                height: 3000,
                fileFormat: "JPEG",
                fileSizeBytes: 5000000
            )
        ],
        onComplete: { _ in }
    )
}
