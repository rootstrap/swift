import SwiftFormatConfiguration

///
public protocol TestDescriptor {

  ///
  var testName: String { get }

  ///
  var configuration: Configuration { get }
}
