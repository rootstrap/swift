import Foundation
import SwiftFormatConfiguration

/// A character set used to filter out non-identifier characters.
fileprivate let nonIdentifierCharacterSet: CharacterSet = {
  var set = CharacterSet()
  set.insert(charactersIn: UnicodeScalar("A")...UnicodeScalar("Z"))
  set.insert(charactersIn: UnicodeScalar("a")...UnicodeScalar("z"))
  set.insert(charactersIn: UnicodeScalar("0")...UnicodeScalar("9"))
  set.insert("_")
  return set.inverted
}()

///
public struct FormatTestDescriptor: TestDescriptor {

  ///
  let testFile: URL

  ///
  public var configuration: Configuration

  ///
  private let name: String

  ///
  let line: Int

  ///
  private(set) var originalText = ""

  ///
  private(set) var expectedText = ""

  ///
  public var testName: String {
    var baseName = testFile.deletingPathExtension().lastPathComponent
      .components(separatedBy: nonIdentifierCharacterSet).joined(separator: "_")
    if let first = baseName.unicodeScalars.first,
      (UnicodeScalar("0")...UnicodeScalar("9")).contains(first)
    {
      baseName = "_" + baseName
    }
    return "\(baseName)_\(name)"
  }

  ///
  init(testFile: URL, configuration: Configuration, name: String, line: Int) {
    self.testFile = testFile
    self.configuration = configuration
    self.name = name.components(separatedBy: nonIdentifierCharacterSet).joined(separator: "_")
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
