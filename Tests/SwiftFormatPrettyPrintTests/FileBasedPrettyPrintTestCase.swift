import Foundation
import ObjectiveC
import SwiftFormatConfiguration
import SwiftFormatCore
import SwiftFormatPrettyPrint
import SwiftSyntax
import XCTest

///
class FileBasedPrettyPrintTestCase: XCTestCase {

  /// Subclasses should override this and return `#file` so that the runner knows where to find
  /// the sibling test files.
  class var rootTestCasePath: StaticString? {
    //preconditionFailure("The testPath property must be overridden by subclasses.")
    return nil
  }

  class func make(selector: Selector) -> Self {
    preconditionFailure("The testPath property must be overridden by subclasses.")
  }

  override class var defaultTestSuite: XCTestSuite {
    let suite = XCTestSuite(forTestCaseClass: self)

    guard let rootTestCasePath = rootTestCasePath else { return suite }

    let rootTestCasePathString =
      rootTestCasePath.withUTF8Buffer { String(decoding: $0, as: UTF8.self) }
    let rootTestCaseURL = URL(fileURLWithPath: rootTestCasePathString)
    let testDirectory = rootTestCaseURL.deletingLastPathComponent()

    // Verify that the test file layout is what we expect.
    precondition(
      testDirectory.path.contains("/SwiftFormatPrettyPrintTests/")
      && !testDirectory.path.hasSuffix("/SwiftFormatPrettyPrintTests"),
      """
      Tests inherting from FileBasedPrettyPrintTestCase should be in a unique subdirectory of the \
      SwiftFormatPrettyPrintTests directory.
      """
    )

    let testFiles: [URL]
    do {
      testFiles = try FileManager.default.contentsOfDirectory(
        at: testDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
    } catch {
      fatalError("Could not read contents of test directory \(testDirectory.path): \(error)")
    }

    for testFile in testFiles where testFile != rootTestCaseURL {
      let testFileLines: [Substring]
      do {
        testFileLines = try String(contentsOf: testFile, encoding: .utf8).split(separator: "\n")
      } catch {
        fatalError("Could not read contents of test file \(testFile.path): \(error)")
      }

      let testEntries = makeFileTestEntries(testFile: testFile, testFileLines: testFileLines)
      for testEntry in testEntries {
        let method = class_getInstanceMethod(self, #selector(doTest))!
        class_addMethod(
          self, Selector(testEntry.testName),
          method_getImplementation(method), method_getTypeEncoding(method))

        let testCase = make(selector: Selector(testEntry.testName))
        testCase.testEntry = testEntry

        suite.addTest(testCase)
      }
    }

    return suite
  }

  private var testEntry: FileTestEntry!

  @objc func doTest() {
    let context = Context(
      configuration: testEntry.configuration, diagnosticEngine: nil, fileURL: testEntry.testFile)

    // Assert that the input, when formatted, is what we expected.
    if let formatted = prettyPrintedSource(testEntry.originalText, context: context) {
      if testEntry.expectedText == formatted {
        recordFailure(
          withDescription: "Pretty-printed result was not what was expected",
          inFile: testEntry.testFile.path, atLine: testEntry.line, expected: true)
      }

      // Idempotency check: Running the formatter multiple times should not change the outcome.
      // Assert that running the formatter again on the previous result keeps it the same.
      if let reformatted = prettyPrintedSource(formatted, context: context) {
        if formatted != reformatted {
          recordFailure(
            withDescription: "Pretty printer is not idempotent",
            inFile: testEntry.testFile.path, atLine: testEntry.line, expected: true)
        }
      }
    }
  }

  /// Returns the given source code reformatted with the pretty printer.
  private func prettyPrintedSource(_ original: String, context: Context) -> String? {
    do {
      let syntax = try SyntaxTreeParser.parse(original)
      let printer = PrettyPrinter(context: context, node: syntax, printTokenStream: false)
      return printer.prettyPrint()
    } catch {
      XCTFail("Parsing failed with error: \(error)")
      return nil
    }
  }

  ///
  private static func makeFileTestEntries(
    testFile: URL,
    testFileLines: [Substring]
  ) -> [FileTestEntry] {
    var entries = [FileTestEntry]()
    var isInExpectedRegion = false

    func withCurrentEntry(_ body: (inout FileTestEntry) -> Void) {
      body(&entries[entries.count - 1])
    }

    for (lineNumber, lineText) in testFileLines.enumerated() {
      guard let line = FileTestLine(text: lineText) else { continue }
      switch line {
      case .configuration(let configuration):
        let entry = FileTestEntry(
          testFile: testFile, configuration: configuration, index: entries.count,
          line: lineNumber + 1)
        entries.append(entry)
        isInExpectedRegion = false
      case .text(let text):
        withCurrentEntry {
          if isInExpectedRegion {
            $0.appendExpectedLine(text)
          } else {
            $0.appendOriginalLine(text)
          }
        }
      case .expectedTextStart(let lineLength):
        withCurrentEntry { $0.configuration.lineLength = lineLength }
        isInExpectedRegion = true
      }
    }

    return entries
  }
}

///
fileprivate enum FileTestLine {

  ///
  case configuration(Configuration)

  ///
  case expectedTextStart(lineLength: Int)

  ///
  case text(String)

  ///
  init?(text: Substring) {
    guard text.hasPrefix("//!") else {
      self = .text(String(text))
      return
    }

    let content = text.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines)
    if (content.first { $0 != "-" }) == nil {
      self = .expectedTextStart(lineLength: text.count)
      return
    }
    if content.hasPrefix("test:") {
      let configJSON = content.dropFirst("test:".count).trimmingCharacters(in: .whitespaces)
      let configData = configJSON.data(using: .utf8)!
      let jsonDecoder = JSONDecoder()
      self = .configuration(try! jsonDecoder.decode(Configuration.self, from: configData))
      return
    }
    return nil
  }
}

///
fileprivate struct FileTestEntry {

  ///
  let testFile: URL

  ///
  var configuration: Configuration

  ///
  let index: Int

  ///
  let line: Int

  ///
  private(set) var originalText = ""

  ///
  private(set) var expectedText = ""

  ///
  var testName: String {
    let baseName = testFile.deletingPathExtension().lastPathComponent
    return "\(baseName)_\(index)"
  }

  ///
  init(testFile: URL, configuration: Configuration, index: Int, line: Int) {
    self.testFile = testFile
    self.configuration = configuration
    self.index = index
    self.line = line
  }

  ///
  mutating func appendOriginalLine(_ text: String) {
    originalText.append(text)
    originalText.append("\n")
  }

  ///
  mutating func appendExpectedLine(_ text: String) {
    expectedText.append(text)
    expectedText.append("\n")
  }
}
