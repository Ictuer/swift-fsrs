//
//  LocalDayBoundaryTests.swift
//  FSRS
//
//  Havivu fork — covers `Date.dayBoundaryTimeZone`, the fork's only divergence.
//  Everything else in this suite directory is upstream's, unmodified.
//

import Foundation
import Testing

@testable import FSRS

/// `.serialized` because `dayBoundaryTimeZone` is process-global: parallel cases
/// would clobber each other's setting.
@Suite(.serialized)
struct LocalDayBoundaryTests {

    private func withBoundary<T>(_ tz: TimeZone, _ body: () throws -> T) rethrows -> T {
        let saved = Date.dayBoundaryTimeZone
        Date.dayBoundaryTimeZone = tz
        defer { Date.dayBoundaryTimeZone = saved }
        return try body()
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    /// The default must stay UTC so every inherited upstream test keeps passing
    /// unmodified, on any machine. Changing this default is the one thing that
    /// would silently break them.
    @Test func defaultBoundaryIsUTC() {
        #expect(Date.dayBoundaryTimeZone.secondsFromGMT() == 0)
    }

    /// The reason the fork exists.
    ///
    /// A UTC boundary lands at 07:00 for a UTC+7 user. Two reviews in one morning
    /// sitting — 06:00 and 08:00 — straddle it, so UTC calls them a day apart and
    /// routes the second through the next-day stability branch instead of
    /// short-term. A local boundary calls them what they are: the same day.
    @Test func morningSittingIsOneDayLocallyButTwoInUTC() {
        let vn = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let first = date("2026-07-16T06:00:00+07:00")
        let second = date("2026-07-16T08:00:00+07:00")

        let local = withBoundary(vn) { Date.dateDiffInDays(from: first, to: second) }
        let utc = withBoundary(TimeZone(secondsFromGMT: 0)!) { Date.dateDiffInDays(from: first, to: second) }

        #expect(local == 0)  // same sitting, same day
        #expect(utc == 1)    // upstream: "one day later"
    }

    /// The mirror case: 23:00 → 06:00 next morning is genuinely a different day,
    /// but UTC folds it into one.
    @Test func overnightGapIsTwoDaysLocallyButOneInUTC() {
        let vn = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let first = date("2026-07-16T23:00:00+07:00")
        let second = date("2026-07-17T06:00:00+07:00")

        let local = withBoundary(vn) { Date.dateDiffInDays(from: first, to: second) }
        let utc = withBoundary(TimeZone(secondsFromGMT: 0)!) { Date.dateDiffInDays(from: first, to: second) }

        #expect(local == 1)  // different day, as the user experienced it
        #expect(utc == 0)    // upstream: "same day"
    }

    /// DST regression guard.
    ///
    /// A spring-forward day is 23 hours. Computing days as `seconds / 86400` —
    /// which is what upstream does, and which is safe only under a DST-free UTC —
    /// floors 23h to 0 and loses the day. This is not hypothetical: with a local
    /// boundary and the old arithmetic, 18 upstream-green scheduler tests failed
    /// under America/New_York while Asia/Ho_Chi_Minh (no DST) stayed green.
    /// The dates here are load-bearing and were computed, not guessed: the gap
    /// must span the midnight *following* the clock change, because that is the
    /// pair of midnights that sits 23h apart.
    ///
    ///     startOfDay(3/7) → startOfDay(3/8):  24h   floor(s/86400) = 1  (misses it)
    ///     startOfDay(3/8) → startOfDay(3/9):  23h   floor(s/86400) = 0  ← the bug
    ///
    /// An earlier draft of this test used 3/7 → 3/8 and passed against *both* the
    /// fixed and the broken implementation — green, and worthless. Verified by
    /// mutation: restore `seconds / 86400` and this test must go red.
    @Test func springForwardDayStillCountsAsOneDay() {
        let ny = TimeZone(identifier: "America/New_York")!
        // 2026-03-08 02:00 is the US spring-forward instant, so the local day
        // 3/8 → 3/9 is 23h long.
        let before = date("2026-03-08T12:00:00-04:00")
        let after = date("2026-03-09T12:00:00-04:00")

        let days = withBoundary(ny) { Date.dateDiffInDays(from: before, to: after) }
        #expect(days == 1)  // seconds/86400 floors 23h to 0 and loses the day
    }

    /// The fall-back mirror: a 25-hour day is still one day, not two.
    ///
    /// `seconds / 86400` happens to survive this one (floor(25h) == 1), so unlike
    /// the spring-forward case it is a guard rather than a regression test — it
    /// pins the direction that a naive "round" instead of "floor" would break.
    @Test func fallBackDayStillCountsAsOneDay() {
        let ny = TimeZone(identifier: "America/New_York")!
        // 2026-11-01 02:00 is the US fall-back instant: local day 11/1 → 11/2 is 25h.
        let before = date("2026-11-01T12:00:00-05:00")
        let after = date("2026-11-02T12:00:00-05:00")

        let days = withBoundary(ny) { Date.dateDiffInDays(from: before, to: after) }
        #expect(days == 1)
    }

    /// Same instant, same timezone → no day has passed, regardless of boundary.
    @Test func zeroGapIsZeroDays() {
        let vn = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let t = date("2026-07-16T12:00:00+07:00")
        #expect(withBoundary(vn) { Date.dateDiffInDays(from: t, to: t) } == 0)
    }

    /// nil `last` → 0, matching the guard upstream relies on for new cards.
    @Test func nilLastReviewIsZeroDays() {
        let vn = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let t = date("2026-07-16T12:00:00+07:00")
        #expect(withBoundary(vn) { Date.dateDiffInDays(from: nil, to: t) } == 0)
    }
}
