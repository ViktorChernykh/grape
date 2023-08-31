import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
	return [
		testCase(GrapeTests.allTests),
		testCase(DiskStorageTests.allTests),
	]
}
#endif
