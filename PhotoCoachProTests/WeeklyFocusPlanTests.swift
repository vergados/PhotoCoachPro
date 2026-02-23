//
//  WeeklyFocusPlanTests.swift
//  PhotoCoachProTests
//

import XCTest
@testable import PhotoCoachPro

final class WeeklyFocusPlanTests: XCTestCase {

    // Bug #89 (fixed): exercise difficulty filter was comparing a constant instead of each exercise's difficulty.

    func testGeneratedPlanHasExercises() {
        let history = SkillHistory(userID: UUID())
        let plan = WeeklyFocusPlan.generate(for: history)
        XCTAssertFalse(plan.exercises.isEmpty)
    }

    func testBeginnerHistoryYieldsBeginnerOrIntermediateExercises() {
        // Empty history → no measurements → weakest skill → beginner-level exercises expected.
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
        var plan = WeeklyFocusPlan.generate(for: SkillHistory(userID: UUID()))
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
