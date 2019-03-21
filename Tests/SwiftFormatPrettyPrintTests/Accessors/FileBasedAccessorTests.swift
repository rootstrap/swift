import Foundation

final class FileBasedAccessorTests: FileBasedPrettyPrintTestCase {
  override class func make(selector: Selector) -> Self {
    return self.init(selector: selector)
  }

  override class var rootTestCasePath: StaticString { return #file }
}
