import XCTest
@testable import PhotoCoachPro

final class WeeklyFocusPlanTests: XCTestCase {

    // Bug #89: filter was `difficulty == .intermediate` (constant true for intermediate requests).
    // Fix:     `$0.difficulty == .intermediate` (checks each exercise's difficulty).

    func testGeneratedPlanHasExercises() {
        let history = SkillHistory(userID: UUID())
        let plan = WeeklyFocusPlan.generate(for: history)
        XCTAssertFalse(plan.exercises.isEmpty)
    }

    func testBeginnerHistoryYieldsBeginnerOrIntermediateExercises() {
        // Empty history → all skills at 0.5 → difficulty = .beginner
        // Filter must return only beginner and intermediate exercises (never advanced)
        let history = SkillHistory(userID: UUID())
        let plan = WeeklyFocusPlan.generate(for: history)
        for exercise in plan.exercises {
            XCTAssertTrue(
                exercise.difficulty == .beginner || exercise.difficulty == .intermediate,
                "Expected .beginner or .intermediate, got .\(exercise.difficulty) for '\(exercise.title)'"
            )
        }
    }

    func testCompletionRate() {
        let history = SkillHistory(userID: UUID())
        var plan = WeeklyFocusPlan.generate(for: history)
        XCTAssertEqual(plan.completionRate, 0)
        guard let first = plan.exercises.first else {
            XCTFail("Plan must have at least one exercise"); return
        }
        plan.completeExercise(first.id)
        XCTAssertGreaterThan(plan.completionRate, 0)
    }

    func testPastPlanIsPast() {
        let past = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let plan = WeeklyFocusPlan(weekStartDate: past, primaryFocus: .lighting)
        XCTAssertTrue(plan.isPast)
        XCTAssertEqual(plan.daysRemaining, 0)
    }
}
