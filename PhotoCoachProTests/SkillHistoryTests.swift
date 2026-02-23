//
//  SkillHistoryTests.swift
//  PhotoCoachProTests
//

import XCTest
@testable import PhotoCoachPro

final class SkillHistoryTests: XCTestCase {

    // Bug #96 (fixed): progressReport milestones filter now has upper bound <= now.

    func testFutureMilestoneExcludedFromReport() {
        var history = SkillHistory(userID: UUID())
        history.milestones.append(SkillHistory.Milestone(
            category: .composition,
            achievedScore: 0.9,
            achievedAt: Date().addingTimeInterval(60 * 60 * 24 * 30), // 30 days in future
            type: .expert,
            photoID: nil
        ))
        let report = history.progressReport(days: 7)
        XCTAssertEqual(report.milestonesAchieved, 0,
                       "Future milestones must not appear in progressReport")
    }

    func testRecentMilestoneIncludedInReport() {
        var history = SkillHistory(userID: UUID())
        history.milestones.append(SkillHistory.Milestone(
            category: .composition,
            achievedScore: 0.7,
            achievedAt: Date().addingTimeInterval(-60 * 60 * 24 * 3), // 3 days ago
            type: .competent,
            photoID: nil
        ))
        let report = history.progressReport(days: 7)
        XCTAssertEqual(report.milestonesAchieved, 1)
    }

    func testOldMilestoneExcludedFromShortWindow() {
        var history = SkillHistory(userID: UUID())
        history.milestones.append(SkillHistory.Milestone(
            category: .composition,
            achievedScore: 0.7,
            achievedAt: Date().addingTimeInterval(-60 * 60 * 24 * 30), // 30 days ago
            type: .competent,
            photoID: nil
        ))
        let report = history.progressReport(days: 7)
        XCTAssertEqual(report.milestonesAchieved, 0,
                       "Milestone from 30 days ago must not appear in 7-day report")
    }

    func testEmptyHistoryReport() {
        let history = SkillHistory(userID: UUID())
        let report = history.progressReport(days: 30)
        XCTAssertEqual(report.milestonesAchieved, 0)
        XCTAssertEqual(report.totalSessions, 0)
        XCTAssertEqual(report.totalPhotos, 0)
    }
}
