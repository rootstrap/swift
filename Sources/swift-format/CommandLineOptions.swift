//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Basic
import Foundation
import SwiftFormat
import Utility

/// Collects the command line options that were passed to `swift-format`.
struct CommandLineOptions {

  /// The path to the JSON configuration file that should be loaded.
  ///
  /// If not specified, the default configuration will be used.
  var configurationPath: String? = nil

  /// The mode in which to run the tool.
  ///
  /// If not specified, the tool will be run in format mode.
  var mode: ToolMode = .format

  /// Advanced options that are useful for developing/debugging but otherwise not meant for general
  /// use.
  var debugOptions: DebugOptions = []

  /// The list of paths to Swift source files that should be formatted or linted.
  var paths: [String] = []
}

/// Process the command line argument strings and returns an object containing their values.
///
/// - Parameters:
///   - commandName: The name of the command that this tool was invoked as.
///   - arguments: The remaining command line arguments after the command name.
/// - Returns: A `CommandLineOptions` value that contains the parsed options.
func processArguments(commandName: String, _ arguments: [String]) -> CommandLineOptions {
  let parser = ArgumentParser(
    commandName: commandName,
    usage: "[options] <filename or path> ...",
    overview: "Format or lint Swift source code.")

  let binder = ArgumentBinder<CommandLineOptions>()
  binder.bind(
    option: parser.add(
      option: "--mode",
      shortName: "-m",
      kind: ToolMode.self,
      usage: "The mode to run swift-format in. Either 'format', 'lint', or 'dump-configuration'."
  )) {
    $0.mode = $1
  }
  binder.bind(
    option: parser.add(
      option: "--version",
      shortName: "-v",
      kind: Bool.self,
      usage: "Prints the version and exists"
  )) { opts, _ in
    opts.mode = .version
  }
  binder.bindArray(
    positional: parser.add(
      positional: "filenames or paths",
      kind: [String].self,
      optional: true,
      strategy: .upToNextOption,
      usage: "One or more input filenames",
      completion: .filename
  )) {
    $0.paths = $1
  }
  binder.bind(
    option: parser.add(
      option: "--configuration",
      kind: String.self,
      usage: "The path to a JSON file containing the configuration of the linter/formatter."
  )) {
    $0.configurationPath = $1
  }

  // Add advanced debug/developer options. These intentionally have no usage strings, which omits
  // them from the `--help` screen to avoid noise for the general user.
  binder.bind(
    option: parser.add(
      option: "--debug-disable-pretty-print",
      kind: Bool.self
  )) {
    $0.debugOptions.set(.disablePrettyPrint, enabled: $1)
  }
  binder.bind(
    option: parser.add(
      option: "--debug-dump-token-stream",
      kind: Bool.self
  )) {
    $0.debugOptions.set(.dumpTokenStream, enabled: $1)
  }

  var opts = CommandLineOptions()
  do {
    let args = try parser.parse(arguments)
    binder.fill(args, into: &opts)

    if opts.mode.requiresFiles && opts.paths.isEmpty {
      throw ArgumentParserError.expectedArguments(parser, ["filenames or paths"])
    }
  } catch {
    stderrStream.write("error: \(error)\n\n")
    parser.printUsage(on: stderrStream)
    exit(1)
  }
  return opts
}
