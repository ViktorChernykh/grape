import XCTest

import GrapeTests
import DiskStorageTests

var tests = [XCTestCaseEntry]()
tests += GrapeTests.allTests()
tests += DiskStorageTests.allTests()
XCTMain(tests)
