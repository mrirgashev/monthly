import XCTest
import WallpaperCore
@testable import MonthlyNative

final class PreferenceStoreTests: XCTestCase {
    func testVersionOneMigratesWithoutLosingCalendarOrAppliedChoices() throws {
        let suite = "MonthlyNative.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var old = Preferences(); old.schemaVersion = 1; old.hasApplied = true
        old.applied.layout = .right; old.applied.calendarIDs = ["fixture-calendar"]
        old.draft.fill = .solid; old.allDisplays = false; old.displayIDs = ["fixture-display"]
        // These are precisely the version-1 keys: optional new fields are absent.
        defaults.set(try JSONEncoder().encode(old), forKey: PreferenceStore.key)
        let (loaded, warning) = PreferenceStore.load(defaults: defaults)
        XCTAssertNil(warning); XCTAssertEqual(loaded.schemaVersion, 2)
        XCTAssertEqual(loaded.applied, old.applied); XCTAssertEqual(loaded.draft, old.draft)
        XCTAssertEqual(loaded.displayIDs, old.displayIDs); XCTAssertTrue(loaded.hasApplied)
        XCTAssertNil(loaded.appliedPlan); XCTAssertEqual(loaded.applied.backgroundChoice.mode, .seasonal)
        XCTAssertEqual(loaded.desktopControlsVisible, old.draft.desktopControls)
    }

    func testCustomColoursAndIndependentDraftPlanPersist() throws {
        let suite = "MonthlyNative.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var value = Preferences(), color = BackgroundChoice(), plan = DesignPlan()
        value.desktopControlsVisible = false
        color.mode = .custom; color.firstHex = "112233"; color.secondHex = "BBDDFF"; color.angle = 47
        value.draft.background = color
        plan.timing = .hourlyCycle; plan.designs = [SavedDesign(name: "My blue", settings: value.draft)]
        value.draftPlan = plan
        try PreferenceStore.save(value, defaults: defaults)
        let (loaded, warning) = PreferenceStore.load(defaults: defaults)
        XCTAssertEqual(loaded, value); XCTAssertNil(warning); XCTAssertNil(loaded.appliedPlan)
    }
    func testPersistenceSeparatesDraftFromApplied() throws {
        let suite = "MonthlyNative.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var value = Preferences(); value.draft.layout = .right; value.hasApplied = true
        value.desktopControlsVisible = true
        try PreferenceStore.save(value, defaults: defaults)
        let (loaded, warning) = PreferenceStore.load(defaults: defaults)
        XCTAssertEqual(loaded, value); XCTAssertNil(warning)
    }
    func testDotVisibilityMigratesLatestChoiceAndSurvivesDesignChanges() throws {
        let suite = "MonthlyNative.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var old = Preferences()
        old.draft.desktopControls = false; old.applied.desktopControls = true
        var plan = DesignPlan(); plan.timing = .hourlyCycle
        plan.designs = [SavedDesign(name: "Previously visible dot", settings: old.applied)]
        old.appliedPlan = plan
        try PreferenceStore.save(old, defaults: defaults)
        var (loaded, warning) = PreferenceStore.load(defaults: defaults)
        XCTAssertNil(warning); XCTAssertEqual(loaded.desktopControlsVisible, false)
        XCTAssertEqual(loaded.appliedPlan, plan)
        loaded.draft = plan.designs[0].settings
        loaded.applied = plan.designs[0].settings
        try PreferenceStore.save(loaded, defaults: defaults)
        let (relaunched, secondWarning) = PreferenceStore.load(defaults: defaults)
        XCTAssertNil(secondWarning); XCTAssertEqual(relaunched.desktopControlsVisible, false)
        XCTAssertEqual(relaunched.appliedPlan, plan)
    }

    func testCorruptAndFuturePreferencesArePreservedForRecovery() throws {
        let suite = "MonthlyNative.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var future = Preferences(); future.schemaVersion = 900
        for data in [Data("broken".utf8), try JSONEncoder().encode(future)] {
            defaults.set(data, forKey: PreferenceStore.key)
            let (loaded, warning) = PreferenceStore.load(defaults: defaults)
            XCTAssertEqual(loaded, Preferences()); XCTAssertNotNil(warning)
            let copies = defaults.dictionaryRepresentation().filter { $0.key.hasPrefix("preferences.recovery.") }
            XCTAssertTrue(copies.values.contains { ($0 as? Data) == data })
        }
    }
}
