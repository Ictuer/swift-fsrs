> ## Fork — adds a configurable day boundary
>
> Fork of [open-spaced-repetition/swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs)
> maintained for [Havivu](https://github.com/Ictuer/havivu). It **adds one knob and
> changes no default**: `Date.dayBoundaryTimeZone` (defaults to UTC, exactly as
> upstream). All 98 upstream tests pass unmodified, in every timezone.
>
> ```swift
> Date.dayBoundaryTimeZone = .current   // opt into a local day boundary
> ```
>
> **Why.** FSRS buckets reviews into days, and upstream pins that boundary to UTC
> midnight. For a UTC+7 user the boundary lands at **07:00 local — mid-morning**:
>
> | User action (UTC+7) | UTC boundary calls it | Correct? |
> |---|---|---|
> | Review 06:00, again 08:00 (2h apart, one sitting) | **"one day later"** → next-day branch | ❌ |
> | Review 08:00, again 23:00 (15h apart, same day) | "same day" → short-term | ✅ |
> | Review 23:00, again 06:00 next day (different day) | **"same day"** → short-term | ❌ |
>
> The two wrong rows diverge ~3x in resulting stability. [Anki](https://docs.ankiweb.net/deck-options.html) —
> the reference implementation for this family — uses a **local** boundary
> (default 4am cutoff), so UTC matches neither user intuition nor Anki.
>
> **One bug fixed along the way.** `dateDiffInDays` computed days as
> `seconds / 86400`, which is safe only under a DST-free UTC. Under a local
> boundary a spring-forward day is 23h, and `floor(23h / 86400)` is 0 — the day
> vanishes silently. Measured: with a local boundary and the old arithmetic, 18
> upstream-green scheduler tests failed under `America/New_York` while
> `Asia/Ho_Chi_Minh` (no DST) stayed green — a VN-only test run would have missed
> it entirely. Now counted with `dateComponents(_:from:to:)`, correct for 23h and
> 25h days alike. Covered by `LocalDayBoundaryTests`, verified by mutation.
>
> **This fork should not outlive its cause.** The knob is offered upstream; if it
> lands there, this fork should be deleted and the dependency pointed back.
> Everything else here is upstream's work, unmodified.

A Swift implementation of FSRS-6.0 (FSRS-5.0 supported via 19-length `w`).

[![codecov](https://codecov.io/gh/open-spaced-repetition/swift-fsrs/graph/badge.svg?token=K2C0Z5PFEH)](https://codecov.io/gh/open-spaced-repetition/swift-fsrs)

```swift
import FSRS

// v5 (default — 19-length w):
let v5 = FSRS(parameters: .init())

// v6 — pass a 21-length w (e.g. the canonical default):
let v6 = FSRS(parameters: .init(w: FSRSDefaults.defaultWv6))

let card = FSRSDefaults().createEmptyCard()
let next = try v6.next(card: card, now: Date(), grade: .good).card
```
