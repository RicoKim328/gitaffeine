import AppKit
import Testing
@testable import gitaffeine

@Test func pillIconIsMenuBarTemplate() {
    let image = PillIcon.image
    #expect(image.isTemplate)
    #expect(image.size == NSSize(width: 18, height: 18))
}
