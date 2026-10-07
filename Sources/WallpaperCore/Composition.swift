import Foundation

public enum VerticalPosition: Sendable { case top, centre, bottom }
public struct Composition: Sendable {
    public let monthColumn: Int
    public let monthPosition: VerticalPosition
    public let numeralColumn: Int
    public let numeralPosition: VerticalPosition
    public let captionColumn: Int
    public let captionPosition: VerticalPosition

    // Independently transcribed from the public twelve-month contact sheet.
    // Columns are zero-based; exact private editor layout rules remain unverified.
    public static func designed(month: Int) -> Composition {
        let all: [Composition] = [
            .init(monthColumn: 1, monthPosition: .top, numeralColumn: 2, numeralPosition: .bottom, captionColumn: 1, captionPosition: .bottom),
            .init(monthColumn: 2, monthPosition: .top, numeralColumn: 3, numeralPosition: .top, captionColumn: 2, captionPosition: .bottom),
            .init(monthColumn: 3, monthPosition: .top, numeralColumn: 1, numeralPosition: .bottom, captionColumn: 3, captionPosition: .bottom),
            .init(monthColumn: 1, monthPosition: .centre, numeralColumn: 2, numeralPosition: .top, captionColumn: 3, captionPosition: .bottom),
            .init(monthColumn: 2, monthPosition: .centre, numeralColumn: 3, numeralPosition: .bottom, captionColumn: 2, captionPosition: .bottom),
            .init(monthColumn: 3, monthPosition: .centre, numeralColumn: 1, numeralPosition: .bottom, captionColumn: 2, captionPosition: .top),
            .init(monthColumn: 1, monthPosition: .centre, numeralColumn: 3, numeralPosition: .top, captionColumn: 2, captionPosition: .bottom),
            .init(monthColumn: 2, monthPosition: .centre, numeralColumn: 1, numeralPosition: .top, captionColumn: 3, captionPosition: .top),
            .init(monthColumn: 3, monthPosition: .centre, numeralColumn: 2, numeralPosition: .top, captionColumn: 1, captionPosition: .top),
            .init(monthColumn: 1, monthPosition: .bottom, numeralColumn: 2, numeralPosition: .bottom, captionColumn: 3, captionPosition: .top),
            .init(monthColumn: 2, monthPosition: .bottom, numeralColumn: 1, numeralPosition: .top, captionColumn: 3, captionPosition: .bottom),
            .init(monthColumn: 3, monthPosition: .bottom, numeralColumn: 2, numeralPosition: .top, captionColumn: 1, captionPosition: .top)
        ]
        return all[max(1, min(12, month)) - 1]
    }
}
