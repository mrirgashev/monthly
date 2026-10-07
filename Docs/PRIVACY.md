# Privacy and local storage

Monthly Native makes no network requests and contains no analytics. It does not require an account. Calendar access is requested only when you choose Connect Calendars. macOS requires Full Access to read events; the app only reads and never creates, changes or sends events. Google and other accounts are provided by macOS Calendar, not a separate sign-in service in this app.

Preferences live in the app's UserDefaults domain. Generated images live in:

```text
~/Library/Application Support/MonthlyNative/Wallpapers/
```

The cache directory and PNG files have owner-only permissions. Expanded schedules place event titles into those images. Exported copies use the destination's normal permissions, and anyone who can see your screen can see displayed events.

Historical PNGs are retained because inactive macOS Spaces can still reference them. To remove them, first set those Spaces to another wallpaper, quit Monthly Native, then remove the generated files. Removing a file that macOS still uses can break that Space's background. Deleting the app alone does not remove these files or preferences.

Automatic hemisphere selection estimates a season from the system timezone's reference city. It does not access location services or perform IP geolocation. You can override it with North or South.
