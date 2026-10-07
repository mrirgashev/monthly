# Architecture

The app deliberately has one state owner, one Calendar adapter, one render worker, and ordinary SwiftUI views. There is no service container, web engine, network backend, third-party package, login helper process, or continuous rendering task.

## State and preview

`AppState` is main-actor isolated. `Preferences` holds independent `draft` and `applied` wallpaper settings, target-display policy, automatic-update policy, and whether the user has ever applied a wallpaper. A first launch does not change the desktop. Draft changes debounce preview generation by 100 ms; a revision token discards stale results. Month previews never pin the live wallpaper to a past/future month. The same renderer receives the same logical display size for previews and final images, with a reduced pixel target for preview performance.

Apply commits the intended settings and performs work asynchronously. Per-display failures stay visible and can be retried with Reapply; the app does not claim an all-display transaction where macOS provides none. Menu/desktop quick actions update the intended applied settings and editor draft together. A system-triggered update only uses applied settings.

## Rendering and image application

`CalendarSnapshot` explicitly uses the Gregorian calendar, fixed English month strings and Monday-first weekdays, with the system timezone. `dateInterval(of: .day)` yields the next local midnight without assuming an 86,400-second day.

`RenderService` is a serial actor. It derives a deterministic SHA-256 key from renderer version, local date, timezone, resolved hemisphere, normalized settings, selected calendar IDs, visible event data, pixel size and logical size. Core Graphics and Core Text draw into an sRGB bitmap; ImageIO encodes PNG. Work happens without a SwiftUI view snapshot or browser. Cached files avoid re-rendering unchanged scenes, and only four preview bitmaps remain in memory.

`AppState` resumes on the main actor, rechecks environment/settings/display identity after rendering, then calls `NSWorkspace.setDesktopImageURL`. A disconnected or changed display invalidates the in-flight request. Each connected screen supplies its own logical dimensions and full backing dimensions. The app generates an exact-aspect image and asks macOS to scale on both axes without clipping. No user desktop images are deleted or edited.

## Lifecycle

One non-repeating timer targets the earlier of the next local midnight and the next saved-design boundary. `DesignPlan` resolves explicit daily slots or ordered hourly/daily cycles against an injected date; nothing is shuffled. Wake and clock changes resolve the currently due design without replaying missed slots. Notification observers handle timezone/system-clock/calendar-day/Calendar-store/display changes, wake and active Space changes. Bursts debounce to one update. Sleep invalidates the timer and invalidates in-flight requests; wake obtains fresh dates and screens. No recurring seconds/minutes timer or display link exists. Closing the editor leaves the status item and observers alive. Quit invalidates observers/tasks and removes overlay windows; the PNG wallpaper remains.

`AppDelegate` owns the AppKit application lifecycle and status item. The app starts in accessory mode; opening the shared editor/Settings window exposes its normal Dock/menu presence, and closing it returns the app to accessory mode. Existing configured installations launch quietly at login. Login registration uses the application itself through `SMAppService`.

## Calendar and data handling

EventKit is requested only through the explicit Connect Calendars action. Calendar authorization is checked before every read. Queries are restricted to a local-day interval and selected calendars; cancelled events are removed, multi-day/all-day and recurring instances come from EventKit. All-day entries precede timed entries, rendered in a 24-hour format matching the public tour. Titles are flattened to one line and truncated visually; additional events produce a count. No event-writing API is used.

Events appear in PNGs only when the schedule is expanded. Cached PNGs are local, under an owner-only directory, with owner-only file permissions. Historical images are retained to avoid invalidating inactive Spaces' wallpaper URLs. The app makes no outbound network requests, including no IP geolocation. Approximate southern hemisphere data comes from IANA timezone reference-city coordinates. Unknown timezones default north and are manually overridable.

## Deliberate native differences

There is no BetterCreating authentication/licensing backend, direct Google OAuth client, Plash configuration page, or paid-account synchronization. Native settings replace the account control. Full desktop interaction uses small non-activating NSPanel overlays; the saved wallpaper itself stays a static PNG. The native editor is an adapted control surface because the actual reference editor could not be accessed without an account/licence. The app does not claim exact equivalence to private reference-product states.

Version 1.2 uses `MainWindowView` to switch between editor and Settings content in one persistent NSWindow. Transient navigation is owned by AppState and does not modify draft wallpaper choices. `Preferences.desktopControlsVisible` stores a global optional visibility override, migrated from the old draft toggle. Changes invoke overlay rebuilding immediately; saved designs and automatic applies cannot override the global choice. The preview follows the same visibility value.
