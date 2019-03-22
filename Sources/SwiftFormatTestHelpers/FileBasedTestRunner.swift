import Foundation
import ObjectiveC
import SwiftFormatConfiguration
import SwiftFormatCore
import XCTest

///
open class FileBasedTestRunner: XCTestCase {

  /// Subclasses must override this and return `#file` so that the runner knows where to find
  /// the sibling test files.
  open class var selfFile: String {
    return ""
  }

  class var testDirectory: URL {
    let selfFileURL = URL(fileURLWithPath: selfFile)
    let basename = selfFileURL.deletingPathExtension().lastPathComponent
    let testSubdir = selfFileURL.deletingLastPathComponent().lastPathComponent

    return selfFileURL
      .deletingLastPathComponent()  // swift-format/Tests/<testSubdir>
      .deletingLastPathComponent()  // swift-format/Tests
      .deletingLastPathComponent()  // swift-format
      .appendingPathComponent("FileBasedTests")
      .appendingPathComponent(testSubdir)
      .appendingPathComponent(basename)
  }

  /// Subclasses must override this to initialize an instance of themselves with the given selector.
  ///
  /// This is unfortunately required because trying to call `self.init` directly within this class
  /// produces an error stating that metatype-based initialization can only be done with a required
  /// initializer. However, we can't make `init(selector:)` required on this class because it would
  /// also force us to implement `init(invocation:)`, which we cannot do from Swift.
  open class func makeTest(selector: Selector) -> Self {
    preconditionFailure("The testPath property must be overridden by subclasses.")
  }

  open override class var defaultTestSuite: XCTestSuite {
    let suite = XCTestSuite(forTestCaseClass: self)

    guard selfFile != "" else { return suite }

    let testFiles: [URL]
    do {
      testFiles = try FileManager.default.contentsOfDirectory(
        at: testDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
    } catch {
      fatalError("Could not read contents of test directory \(testDirectory.path): \(error)")
    }

    for testFile in testFiles where testFile.path.hasSuffix(".swift") {
      let testEntries = extractTests(from: testFile)

      // For each test entry that we extracted from the file, we register a new method with a
      // dynamically computed name that points to the same implementation as our `doTest` method.
      // Since XCTest only uses the method name and not the `XCTestCase.name` property to determine
      // the test name that it logs, this allows Xcode to display more meaningful names in its test
      // results UI. (Otherwise, all the items in the tree would have the same name.)
      for testDescriptor in testEntries {
        let method = class_getInstanceMethod(self, #selector(executeTest))!
        guard class_addMethod(
          self, Selector(testDescriptor.testName),
          method_getImplementation(method), method_getTypeEncoding(method))
          else {
            fatalError("Could not add a test method named \(testDescriptor.testName)")
        }

        let testCase = makeTest(selector: Selector(testDescriptor.testName))
        testCase.testDescriptor = testDescriptor

        suite.addTest(testCase)
      }
    }

    return suite
  }

  /// Returns a list of test descriptors corresponding to tests extracted from the given file.
  open class func extractTests(from testFile: URL) -> [TestDescriptor] {
    preconditionFailure("extractTests(from:) must be overriden by a subclass.")
  }

  /// The descriptor of the current test being executed.
  public private(set) var testDescriptor: TestDescriptor!

  /// Executes the logic for the current test as specified by the `testDescriptor` property.
  @objc open func executeTest() {
    preconditionFailure("executeTest() must be overriden by a subclass.")
  }
}
