import XCTest
@testable import PhotoCoachPro
import CoreGraphics

final class ExportSettingsTests: XCTestCase {

    // MARK: - Color Space (Bug #92 — fixed)

    func testProPhotoRGBIsNotGenericLinear() {
        let cs = ExportSettings.ColorSpaceOption.proPhotoRGB.colorSpace
        XCTAssertNotNil(cs)
        let name = cs?.name as String?
        XCTAssertFalse(name == CGColorSpace.genericRGBLinear as String,
                       "proPhotoRGB must not map to genericRGBLinear")
    }

    func testProPhotoRGBMapsToRec2020() {
        let cs = ExportSettings.ColorSpaceOption.proPhotoRGB.colorSpace
        let name = cs?.name as String?
        XCTAssertEqual(name, CGColorSpace.itur_2020 as String)
    }

    func testAllColorSpacesNonNil() {
        for option in ExportSettings.ColorSpaceOption.allCases {
            XCTAssertNotNil(option.colorSpace, "\(option.rawValue) returned nil CGColorSpace")
        }
    }

    // MARK: - Resolution (Bug #94 — UNFIXED, expect FAIL)

    func testLargeIs4K() {
        XCTAssertEqual(ExportSettings.ResolutionOption.large.maxDimension, 3840)
    }

    func testSmallIs1080p() {
        XCTAssertEqual(ExportSettings.ResolutionOption.small.maxDimension, 1920)
    }

    func testMediumIsTrue2K() {
        // "Medium (2K)" should return 2048. Currently returns 2560 — BUG #94
        XCTAssertEqual(ExportSettings.ResolutionOption.medium.maxDimension, 2048,
                       "Medium resolution labeled '2K' must be 2048px, not 2560px")
    }

    func testOriginalHasNoMaxDimension() {
        XCTAssertNil(ExportSettings.ResolutionOption.original.maxDimension)
    }

    // MARK: - ExportJob lifecycle (Bug #95 — UNFIXED, expect FAIL)

    func testCompleteSetProgressToOne() {
        var job = makeJob()
        job.updateProgress(0.5)
        job.complete(url: URL(fileURLWithPath: "/tmp/out.jpg"))
        XCTAssertEqual(job.progress, 1.0)
        XCTAssertEqual(job.status, .completed)
    }

    func testCancelResetsProgress() {
        // cancel() must reset progress to 0.0 — BUG #95 (currently leaves it at mid-flight value)
        var job = makeJob()
        job.updateProgress(0.6)
        job.cancel()
        XCTAssertEqual(job.progress, 0.0,
                       "cancel() must reset progress to 0.0")
        XCTAssertEqual(job.status, .cancelled)
    }

    func testUpdateProgressClamps() {
        var job = makeJob()
        job.updateProgress(1.5)
        XCTAssertEqual(job.progress, 1.0)
        job.updateProgress(-0.5)
        XCTAssertEqual(job.progress, 0.0)
    }

    func testUpdateProgressTransitionsToProcessing() {
        var job = makeJob()
        XCTAssertEqual(job.status, .pending)
        job.updateProgress(0.1)
        XCTAssertEqual(job.status, .processing)
    }

    // MARK: - Helpers

    private func makeJob() -> ExportJob {
        ExportJob(photoID: UUID(), settings: ExportSettings())
    }
}
