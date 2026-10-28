import Foundation
import Testing
@testable import Thermals

struct UpdaterConfigurationTests {
    @Test func signedFeedVerifiesBeforeExtraction() {
        let info = Bundle(for: Updater.self).infoDictionary
        #expect(info?["SURequireSignedFeed"] as? Bool == true)
        #expect(info?["SUVerifyUpdateBeforeExtraction"] as? Bool == true)
    }
}
