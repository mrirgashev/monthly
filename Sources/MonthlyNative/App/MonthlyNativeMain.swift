import AppKit

@main enum MonthlyNativeMain {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--render-samples") {
            do { try SampleExporter.run() } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(1)
            }
            return
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}
