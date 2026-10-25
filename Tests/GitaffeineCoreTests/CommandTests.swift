import Foundation
import Testing
@testable import GitaffeineCore

@Test func returnsOutputWithinTimeLimit() throws {
    let output = try Command.run(URL(fileURLWithPath: "/bin/echo"), ["hi"], timeout: 5)
    #expect(String(decoding: output, as: UTF8.self) == "hi\n")
}

@Test func stopsACommandThatRunsTooLong() {
    let clock = ContinuousClock()
    let elapsed = clock.measure {
        #expect(throws: Command.TimedOut.self) {
            try Command.run(URL(fileURLWithPath: "/bin/sleep"), ["10"], timeout: 0.5)
        }
    }
    #expect(elapsed < .seconds(5))
}
