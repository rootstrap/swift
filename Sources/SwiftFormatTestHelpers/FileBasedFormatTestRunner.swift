import Foundation
import SwiftFormatConfiguration
import SwiftFormatCore
import SwiftFormatPrettyPrint
import SwiftSyntax

/// The superclass for file-based format tests.
open class FileBasedFormatTestRunner: FileBasedTestRunner {

  private var formatTestDescriptor: FormatTestDescriptor {
    return testDescriptor as! FormatTestDescriptor
  }

  open override func executeTest() {
    let context = Context(
      configuration: testDescriptor.configuration, diagnosticEngine: nil,
      fileURL: formatTestDescriptor.testFile)

    do {
      // Assert that the input, when formatted, is what we expected.
      if let formatted
        = try prettyPrintedSource(formatTestDescriptor.originalText, context: context)
      {
        if formatTestDescriptor.expectedText != formatted {
          // TODO(allevato): Print a diff here.
          recordFailure(
            withDescription: """
              Pretty-printed result was not what was expected:

              EXPECTED
              ---
              \(formatTestDescriptor.expectedText)

              ACTUAL
              ---
              \(formatted)
              """,
            inFile: formatTestDescriptor.testFile.path, atLine: formatTestDescriptor.line,
            expected: true)
        }

        // Idempotency check: Running the formatter multiple times should not change the outcome.
        // Assert that running the formatter again on the previous result keeps it the same.
        if let reformatted = try prettyPrintedSource(formatted, context: context) {
          if formatted != reformatted {
            recordFailure(
              withDescription: """
                Pretty printer is not idempotent

                FORMATTED
                ---
                \(formatted)

                RE-FORMATTED
                ---
                \(reformatted)
                """,
              inFile: formatTestDescriptor.testFile.path, atLine: formatTestDescriptor.line,
              expected: true)
          }
        }
      }
    } catch {
      recordFailure(
        withDescription: "Parsing failed with error: \(error)",
        inFile: formatTestDescriptor.testFile.path, atLine: formatTestDescriptor.line,
        expected: false)
    }
  }

  open override class func extractTests(from testFile: URL) -> [TestDescriptor] {
    let testFileLines: [Substring]
    do {
      testFileLines = try String(contentsOf: testFile, encoding: .utf8).split(separator: "\n")
    } catch {
      fatalError("Could not read contents of test file \(testFile.path): \(error)")
    }

    var entries = [FormatTestDescriptor]()
    var isInExpectedRegion = false

    /// Helper function that makes it easier to update the current entry in-place below.
    func withCurrentEntry(_ body: (inout FormatTestDescriptor) -> Void) {
      body(&entries[entries.count - 1])
    }

    for (lineNumber, lineText) in testFileLines.enumerated() {
      guard let line = TestLine(text: lineText) else { continue }

      switch line {
      case .newTestStart(let name, let configuration):
        let entry = FormatTestDescriptor(
          testFile: testFile, configuration: configuration ?? Configuration(),
          name: name ?? "\(entries.count)", line: lineNumber + 1)
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

  /// Returns the given source code reformatted with the pretty printer.
  private func prettyPrintedSource(_ original: String, context: Context) throws -> String? {
    let syntax = try SyntaxTreeParser.parse(original)
    let printer = PrettyPrinter(context: context, node: syntax, printTokenStream: false)
    return printer.prettyPrint()
  }
}

/// Categorizes a line of input in a format test file, for the state machine that extracts the
/// tests.
fileprivate enum TestLine {

  /// A line that starts a new test, with an optional name and JSON configuration payload.
  case newTestStart(name: String?, configuration: Configuration?)

  /// A line that represents the start of the expected formatted output, the length of which
  /// specifies the margin.
  case expectedTextStart(lineLength: Int)

  /// A line of plain text, which will be accumulated in the input or expected text.
  case text(String)

  /// Creates a new value that classifies the given text.
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
      let restOfLine = content.dropFirst("test:".count).trimmingCharacters(in: .whitespaces)

      var name: String? = nil
      var configuration: Configuration? = nil

      let openBraceIndex = restOfLine.firstIndex(of: "{")
      if let openBraceIndex = openBraceIndex {
        name = restOfLine[..<openBraceIndex].trimmingCharacters(in: .whitespaces)
        let configData = restOfLine[openBraceIndex...].data(using: .utf8)!
        let jsonDecoder = JSONDecoder()
        configuration = try! jsonDecoder.decode(Configuration.self, from: configData)
      } else {
        name = restOfLine.trimmingCharacters(in: .whitespaces)
      }

      if name?.isEmpty == true {
        name = nil
      }

      self = .newTestStart(name: name, configuration: configuration)
      return
    }
    return nil
  }
}
