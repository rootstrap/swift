import XCTest

import CommonMarkTests
import SwiftFormatPrettyPrintTests
import SwiftFormatRulesTests
import SwiftFormatWhitespaceLinterTests

var tests = [XCTestCaseEntry]()
tests += CommonMarkTests.__allTests()
tests += SwiftFormatPrettyPrintTests.__allTests()
tests += SwiftFormatRulesTests.__allTests()
tests += SwiftFormatWhitespaceLinterTests.__allTests()

XCTMain(tests)
