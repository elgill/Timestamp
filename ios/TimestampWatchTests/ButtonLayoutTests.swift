import Testing
@testable import TimestampWatch

/// How the record buttons are split into pages and rows.
struct ButtonLayoutTests {
    func buttons(_ count: Int) -> [RecordButtonConfig] {
        (1...max(count, 1)).prefix(count).map { RecordButtonConfig(name: "B\($0)", color: .defaultColor) }
    }

    /// The number of buttons in each row of each page.
    func shape(_ count: Int) -> [[Int]] {
        ButtonLayout.pages(buttons(count)).map { $0.rows.map(\.count) }
    }

    @Test func withNoButtonsThereIsOneUnnamedButton() {
        #expect(ButtonLayout.pages([]) == [ButtonPage(rows: [[nil]])])
    }

    @Test func upToThreeButtonsAreFullWidth() {
        #expect(shape(1) == [[1]])
        #expect(shape(2) == [[1, 1]])
        #expect(shape(3) == [[1, 1, 1]])
    }

    @Test func fourToSixGoTwoToARow() {
        #expect(shape(4) == [[2, 2]])
        #expect(shape(5) == [[2, 2, 1]])
        #expect(shape(6) == [[2, 2, 2]])
    }

    @Test func moreThanSixStartAnotherPage() {
        #expect(shape(7) == [[2, 2, 2], [1]])
        #expect(shape(9) == [[2, 2, 2], [1, 1, 1]])
        #expect(shape(12) == [[2, 2, 2], [2, 2, 2]])
        #expect(shape(30).count == 5)
    }

    @Test func theButtonsKeepTheirOrder() {
        let names = ButtonLayout.pages(buttons(13))
            .flatMap(\.rows).flatMap { $0 }.map { $0?.name }
        #expect(names == buttons(13).map(\.name))
    }
}
