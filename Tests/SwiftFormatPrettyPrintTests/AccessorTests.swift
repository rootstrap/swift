import Foundation
import SwiftFormatTestHelpers

final class FileBasedAccessorTests: FileBasedFormatTestRunner {
  override class func makeTest(selector: Selector) -> Self { return self.init(selector: selector) }
  override class var selfFile: String { return #file }
}
