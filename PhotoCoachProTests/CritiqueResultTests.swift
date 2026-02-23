import XCTest
@testable import PhotoCoachPro

final class CritiqueResultTests: XCTestCase {

    typealias Rating = CritiqueResult.CategoryScore.Rating

    // MARK: - Rating thresholds

    func testExcellent() {
        XCTAssertEqual(Rating(score: 1.0), .excellent)
        XCTAssertEqual(Rating(score: 0.9), .excellent)
    }

    func testGood() {
        XCTAssertEqual(Rating(score: 0.89), .good)
        XCTAssertEqual(Rating(score: 0.75), .good)
    }

    func testFair() {
        XCTAssertEqual(Rating(score: 0.74), .fair)
        XCTAssertEqual(Rating(score: 0.6),  .fair)
    }

    func testNeedsWork() {
        XCTAssertEqual(Rating(score: 0.59), .needsWork)
        XCTAssertEqual(Rating(score: 0.4),  .needsWork)
    }

    func testPoor() {
        XCTAssertEqual(Rating(score: 0.39), .poor)
        XCTAssertEqual(Rating(score: 0.0),  .poor)
    }

    // MARK: - Computed overallRating

    func testOverallRatingDerivedFromScore() {
        XCTAssertEqual(makeResult(score: 0.95).overallRating, .excellent)
        XCTAssertEqual(makeResult(score: 0.3).overallRating,  .poor)
    }

    // MARK: - Helpers

    private func makeResult(score: Double) -> CritiqueResult {
        let cat = CritiqueResult.CategoryScore(score: score, notes: "")
        return CritiqueResult(
            photoID: UUID(),
            overallScore: score,
            overallSummary: "",
            topImprovements: [],
            categories: CritiqueResult.CategoryBreakdown(
                composition: cat, light: cat,
                focus: cat, color: cat,
                background: cat, story: cat
            ),
            editGuidance: []
        )
    }
}
