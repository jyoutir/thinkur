import Foundation
import Testing
@testable import thinkur

@Suite("Synthetic Dataset", .serialized)
struct SyntheticDatasetTests {
    private let pipeline = TextPostProcessor(processors: [
        SelfCorrectionProcessor(),
        FillerRemovalProcessor(),
        SpokenPunctuationProcessor(),
        SmartFormattingProcessor(),
        PausePunctuationProcessor(),
        CapitalizationProcessor(),
        StyleAdaptationProcessor(),
        ListDetectionProcessor(),
        CodeContextProcessor(),
    ])

    private struct TestCase: Decodable {
        let id: String
        let category: String
        let subcategory: String
        let description: String
        let raw: String
        let expected_casual: String
        let expected_formal: String
        let expected_neutral: String
        let notes: String?
        let tags: [String]
    }

    private struct TestDataset: Decodable {
        let test_cases: [TestCase]
    }

    private static let testCases: [TestCase] = {
        // Navigate from this source file up to the package root
        var dir = URL(fileURLWithPath: #filePath)
        // Go up: SyntheticDatasetTests.swift -> Integration -> thinkurTests -> Tests -> (package root)
        for _ in 0..<4 { dir = dir.deletingLastPathComponent() }
        let url = dir.appendingPathComponent("docs/post-processing/test-dataset.json")
        guard let data = try? Data(contentsOf: url),
              let dataset = try? JSONDecoder().decode(TestDataset.self, from: data) else {
            return []
        }
        return dataset.test_cases
    }()

    private func ctx(style: AppStyle) -> ProcessingContext {
        ProcessingContext(
            frontmostAppBundleID: style == .code ? "com.apple.dt.Xcode" : "com.test",
            frontmostAppName: style == .code ? "Xcode" : "Test",
            wordTimings: [],
            appStyle: style
        )
    }

    private func run(_ id: String, style: AppStyle, expected: (TestCase) -> String) {
        guard let tc = Self.testCases.first(where: { $0.id == id }) else {
            Issue.record("Test case \(id) not found in dataset")
            return
        }
        let result = pipeline.process(tc.raw, context: ctx(style: style)).text
        let exp = expected(tc)
        #expect(result == exp, "[\(id)] style=\(style)\n  raw: \(tc.raw)\n  got: \(result)\n  exp: \(exp)")
    }

    // MARK: - Self-Correction

    @Test func SC001_casual() { run("SC-001", style: .casual) { $0.expected_casual } }
    @Test func SC001_formal() { run("SC-001", style: .formal) { $0.expected_formal } }
    @Test func SC001_neutral() { run("SC-001", style: .standard) { $0.expected_neutral } }

    @Test func SC002_casual() { run("SC-002", style: .casual) { $0.expected_casual } }
    @Test func SC002_formal() { run("SC-002", style: .formal) { $0.expected_formal } }
    @Test func SC002_neutral() { run("SC-002", style: .standard) { $0.expected_neutral } }

    @Test func SC003_casual() { run("SC-003", style: .casual) { $0.expected_casual } }
    @Test func SC003_formal() { run("SC-003", style: .formal) { $0.expected_formal } }
    @Test func SC003_neutral() { run("SC-003", style: .standard) { $0.expected_neutral } }

    @Test func SC004_casual() { run("SC-004", style: .casual) { $0.expected_casual } }
    @Test func SC004_formal() { run("SC-004", style: .formal) { $0.expected_formal } }
    @Test func SC004_neutral() { run("SC-004", style: .standard) { $0.expected_neutral } }

    @Test func SC005_casual() { run("SC-005", style: .casual) { $0.expected_casual } }
    @Test func SC005_formal() { run("SC-005", style: .formal) { $0.expected_formal } }
    @Test func SC005_neutral() { run("SC-005", style: .standard) { $0.expected_neutral } }

    @Test func SC006_casual() { run("SC-006", style: .casual) { $0.expected_casual } }
    @Test func SC006_formal() { run("SC-006", style: .formal) { $0.expected_formal } }
    @Test func SC006_neutral() { run("SC-006", style: .standard) { $0.expected_neutral } }

    // MARK: - Self-Correction False Positives

    @Test func SCFP001_casual() { run("SC-FP-001", style: .casual) { $0.expected_casual } }
    @Test func SCFP001_formal() { run("SC-FP-001", style: .formal) { $0.expected_formal } }
    @Test func SCFP001_neutral() { run("SC-FP-001", style: .standard) { $0.expected_neutral } }

    @Test func SCFP002_casual() { run("SC-FP-002", style: .casual) { $0.expected_casual } }
    @Test func SCFP002_formal() { run("SC-FP-002", style: .formal) { $0.expected_formal } }
    @Test func SCFP002_neutral() { run("SC-FP-002", style: .standard) { $0.expected_neutral } }

    @Test func SCFP003_casual() { run("SC-FP-003", style: .casual) { $0.expected_casual } }
    @Test func SCFP003_formal() { run("SC-FP-003", style: .formal) { $0.expected_formal } }
    @Test func SCFP003_neutral() { run("SC-FP-003", style: .standard) { $0.expected_neutral } }

    @Test func SCFP004_casual() { run("SC-FP-004", style: .casual) { $0.expected_casual } }
    @Test func SCFP004_formal() { run("SC-FP-004", style: .formal) { $0.expected_formal } }
    @Test func SCFP004_neutral() { run("SC-FP-004", style: .standard) { $0.expected_neutral } }

    @Test func SCFP005_casual() { run("SC-FP-005", style: .casual) { $0.expected_casual } }
    @Test func SCFP005_formal() { run("SC-FP-005", style: .formal) { $0.expected_formal } }
    @Test func SCFP005_neutral() { run("SC-FP-005", style: .standard) { $0.expected_neutral } }

    @Test func SCFP006_casual() { run("SC-FP-006", style: .casual) { $0.expected_casual } }
    @Test func SCFP006_formal() { run("SC-FP-006", style: .formal) { $0.expected_formal } }
    @Test func SCFP006_neutral() { run("SC-FP-006", style: .standard) { $0.expected_neutral } }

    @Test func SCFP007_casual() { run("SC-FP-007", style: .casual) { $0.expected_casual } }
    @Test func SCFP007_formal() { run("SC-FP-007", style: .formal) { $0.expected_formal } }
    @Test func SCFP007_neutral() { run("SC-FP-007", style: .standard) { $0.expected_neutral } }

    @Test func SCFP008_casual() { run("SC-FP-008", style: .casual) { $0.expected_casual } }
    @Test func SCFP008_formal() { run("SC-FP-008", style: .formal) { $0.expected_formal } }
    @Test func SCFP008_neutral() { run("SC-FP-008", style: .standard) { $0.expected_neutral } }

    @Test func SCFP009_casual() { run("SC-FP-009", style: .casual) { $0.expected_casual } }
    @Test func SCFP009_formal() { run("SC-FP-009", style: .formal) { $0.expected_formal } }
    @Test func SCFP009_neutral() { run("SC-FP-009", style: .standard) { $0.expected_neutral } }

    @Test func SCFP010_casual() { run("SC-FP-010", style: .casual) { $0.expected_casual } }
    @Test func SCFP010_formal() { run("SC-FP-010", style: .formal) { $0.expected_formal } }
    @Test func SCFP010_neutral() { run("SC-FP-010", style: .standard) { $0.expected_neutral } }

    @Test func SCFP011_casual() { run("SC-FP-011", style: .casual) { $0.expected_casual } }
    @Test func SCFP011_formal() { run("SC-FP-011", style: .formal) { $0.expected_formal } }
    @Test func SCFP011_neutral() { run("SC-FP-011", style: .standard) { $0.expected_neutral } }

    @Test func SCFP012_casual() { run("SC-FP-012", style: .casual) { $0.expected_casual } }
    @Test func SCFP012_formal() { run("SC-FP-012", style: .formal) { $0.expected_formal } }
    @Test func SCFP012_neutral() { run("SC-FP-012", style: .standard) { $0.expected_neutral } }

    @Test func SCFP013_casual() { run("SC-FP-013", style: .casual) { $0.expected_casual } }
    @Test func SCFP013_formal() { run("SC-FP-013", style: .formal) { $0.expected_formal } }
    @Test func SCFP013_neutral() { run("SC-FP-013", style: .standard) { $0.expected_neutral } }

    // MARK: - Filler Removal

    @Test func FR001_casual() { run("FR-001", style: .casual) { $0.expected_casual } }
    @Test func FR001_formal() { run("FR-001", style: .formal) { $0.expected_formal } }
    @Test func FR001_neutral() { run("FR-001", style: .standard) { $0.expected_neutral } }

    @Test func FR002_casual() { run("FR-002", style: .casual) { $0.expected_casual } }
    @Test func FR002_formal() { run("FR-002", style: .formal) { $0.expected_formal } }
    @Test func FR002_neutral() { run("FR-002", style: .standard) { $0.expected_neutral } }

    @Test func FR003_casual() { run("FR-003", style: .casual) { $0.expected_casual } }
    @Test func FR003_formal() { run("FR-003", style: .formal) { $0.expected_formal } }
    @Test func FR003_neutral() { run("FR-003", style: .standard) { $0.expected_neutral } }

    @Test func FR004_casual() { run("FR-004", style: .casual) { $0.expected_casual } }
    @Test func FR004_formal() { run("FR-004", style: .formal) { $0.expected_formal } }
    @Test func FR004_neutral() { run("FR-004", style: .standard) { $0.expected_neutral } }

    @Test func FR005_casual() { run("FR-005", style: .casual) { $0.expected_casual } }
    @Test func FR005_formal() { run("FR-005", style: .formal) { $0.expected_formal } }
    @Test func FR005_neutral() { run("FR-005", style: .standard) { $0.expected_neutral } }

    @Test func FR006_casual() { run("FR-006", style: .casual) { $0.expected_casual } }
    @Test func FR006_formal() { run("FR-006", style: .formal) { $0.expected_formal } }
    @Test func FR006_neutral() { run("FR-006", style: .standard) { $0.expected_neutral } }

    @Test func FR007_casual() { run("FR-007", style: .casual) { $0.expected_casual } }
    @Test func FR007_formal() { run("FR-007", style: .formal) { $0.expected_formal } }
    @Test func FR007_neutral() { run("FR-007", style: .standard) { $0.expected_neutral } }

    @Test func FR008_casual() { run("FR-008", style: .casual) { $0.expected_casual } }
    @Test func FR008_formal() { run("FR-008", style: .formal) { $0.expected_formal } }
    @Test func FR008_neutral() { run("FR-008", style: .standard) { $0.expected_neutral } }

    @Test func FR009_casual() { run("FR-009", style: .casual) { $0.expected_casual } }
    @Test func FR009_formal() { run("FR-009", style: .formal) { $0.expected_formal } }
    @Test func FR009_neutral() { run("FR-009", style: .standard) { $0.expected_neutral } }

    @Test func FR010_casual() { run("FR-010", style: .casual) { $0.expected_casual } }
    @Test func FR010_formal() { run("FR-010", style: .formal) { $0.expected_formal } }
    @Test func FR010_neutral() { run("FR-010", style: .standard) { $0.expected_neutral } }

    @Test func FR011_casual() { run("FR-011", style: .casual) { $0.expected_casual } }
    @Test func FR011_formal() { run("FR-011", style: .formal) { $0.expected_formal } }
    @Test func FR011_neutral() { run("FR-011", style: .standard) { $0.expected_neutral } }

    @Test func FR012_casual() { run("FR-012", style: .casual) { $0.expected_casual } }
    @Test func FR012_formal() { run("FR-012", style: .formal) { $0.expected_formal } }
    @Test func FR012_neutral() { run("FR-012", style: .standard) { $0.expected_neutral } }

    // MARK: - Spoken Punctuation

    @Test func SP001_casual() { run("SP-001", style: .casual) { $0.expected_casual } }
    @Test func SP001_formal() { run("SP-001", style: .formal) { $0.expected_formal } }
    @Test func SP001_neutral() { run("SP-001", style: .standard) { $0.expected_neutral } }

    @Test func SP002_casual() { run("SP-002", style: .casual) { $0.expected_casual } }
    @Test func SP002_formal() { run("SP-002", style: .formal) { $0.expected_formal } }
    @Test func SP002_neutral() { run("SP-002", style: .standard) { $0.expected_neutral } }

    @Test func SP003_casual() { run("SP-003", style: .casual) { $0.expected_casual } }
    @Test func SP003_formal() { run("SP-003", style: .formal) { $0.expected_formal } }
    @Test func SP003_neutral() { run("SP-003", style: .standard) { $0.expected_neutral } }

    @Test func SP004_casual() { run("SP-004", style: .casual) { $0.expected_casual } }
    @Test func SP004_formal() { run("SP-004", style: .formal) { $0.expected_formal } }
    @Test func SP004_neutral() { run("SP-004", style: .standard) { $0.expected_neutral } }

    @Test func SP005_casual() { run("SP-005", style: .casual) { $0.expected_casual } }
    @Test func SP005_formal() { run("SP-005", style: .formal) { $0.expected_formal } }
    @Test func SP005_neutral() { run("SP-005", style: .standard) { $0.expected_neutral } }

    @Test func SP006_casual() { run("SP-006", style: .casual) { $0.expected_casual } }
    @Test func SP006_formal() { run("SP-006", style: .formal) { $0.expected_formal } }
    @Test func SP006_neutral() { run("SP-006", style: .standard) { $0.expected_neutral } }

    @Test func SP007_casual() { run("SP-007", style: .casual) { $0.expected_casual } }
    @Test func SP007_formal() { run("SP-007", style: .formal) { $0.expected_formal } }
    @Test func SP007_neutral() { run("SP-007", style: .standard) { $0.expected_neutral } }

    @Test func SP008_casual() { run("SP-008", style: .casual) { $0.expected_casual } }
    @Test func SP008_formal() { run("SP-008", style: .formal) { $0.expected_formal } }
    @Test func SP008_neutral() { run("SP-008", style: .standard) { $0.expected_neutral } }

    @Test func SP009_casual() { run("SP-009", style: .casual) { $0.expected_casual } }
    @Test func SP009_formal() { run("SP-009", style: .formal) { $0.expected_formal } }
    @Test func SP009_neutral() { run("SP-009", style: .standard) { $0.expected_neutral } }

    @Test func SP010_casual() { run("SP-010", style: .casual) { $0.expected_casual } }
    @Test func SP010_formal() { run("SP-010", style: .formal) { $0.expected_formal } }
    @Test func SP010_neutral() { run("SP-010", style: .standard) { $0.expected_neutral } }

    // MARK: - Number Conversion

    @Test func NC001_casual() { run("NC-001", style: .casual) { $0.expected_casual } }
    @Test func NC001_formal() { run("NC-001", style: .formal) { $0.expected_formal } }
    @Test func NC001_neutral() { run("NC-001", style: .standard) { $0.expected_neutral } }

    @Test func NC002_casual() { run("NC-002", style: .casual) { $0.expected_casual } }
    @Test func NC002_formal() { run("NC-002", style: .formal) { $0.expected_formal } }
    @Test func NC002_neutral() { run("NC-002", style: .standard) { $0.expected_neutral } }

    @Test func NC003_casual() { run("NC-003", style: .casual) { $0.expected_casual } }
    @Test func NC003_formal() { run("NC-003", style: .formal) { $0.expected_formal } }
    @Test func NC003_neutral() { run("NC-003", style: .standard) { $0.expected_neutral } }

    @Test func NC004_casual() { run("NC-004", style: .casual) { $0.expected_casual } }
    @Test func NC004_formal() { run("NC-004", style: .formal) { $0.expected_formal } }
    @Test func NC004_neutral() { run("NC-004", style: .standard) { $0.expected_neutral } }

    @Test func NC005_casual() { run("NC-005", style: .casual) { $0.expected_casual } }
    @Test func NC005_formal() { run("NC-005", style: .formal) { $0.expected_formal } }
    @Test func NC005_neutral() { run("NC-005", style: .standard) { $0.expected_neutral } }

    @Test func NC006_casual() { run("NC-006", style: .casual) { $0.expected_casual } }
    @Test func NC006_formal() { run("NC-006", style: .formal) { $0.expected_formal } }
    @Test func NC006_neutral() { run("NC-006", style: .standard) { $0.expected_neutral } }

    @Test func NC007_casual() { run("NC-007", style: .casual) { $0.expected_casual } }
    @Test func NC007_formal() { run("NC-007", style: .formal) { $0.expected_formal } }
    @Test func NC007_neutral() { run("NC-007", style: .standard) { $0.expected_neutral } }

    @Test func NC008_casual() { run("NC-008", style: .casual) { $0.expected_casual } }
    @Test func NC008_formal() { run("NC-008", style: .formal) { $0.expected_formal } }
    @Test func NC008_neutral() { run("NC-008", style: .standard) { $0.expected_neutral } }

    @Test func NC009_casual() { run("NC-009", style: .casual) { $0.expected_casual } }
    @Test func NC009_formal() { run("NC-009", style: .formal) { $0.expected_formal } }
    @Test func NC009_neutral() { run("NC-009", style: .standard) { $0.expected_neutral } }

    @Test func NC010_casual() { run("NC-010", style: .casual) { $0.expected_casual } }
    @Test func NC010_formal() { run("NC-010", style: .formal) { $0.expected_formal } }
    @Test func NC010_neutral() { run("NC-010", style: .standard) { $0.expected_neutral } }

    @Test func NC011_casual() { run("NC-011", style: .casual) { $0.expected_casual } }
    @Test func NC011_formal() { run("NC-011", style: .formal) { $0.expected_formal } }
    @Test func NC011_neutral() { run("NC-011", style: .standard) { $0.expected_neutral } }

    @Test func NC012_casual() { run("NC-012", style: .casual) { $0.expected_casual } }
    @Test func NC012_formal() { run("NC-012", style: .formal) { $0.expected_formal } }
    @Test func NC012_neutral() { run("NC-012", style: .standard) { $0.expected_neutral } }

    @Test func NC013_casual() { run("NC-013", style: .casual) { $0.expected_casual } }
    @Test func NC013_formal() { run("NC-013", style: .formal) { $0.expected_formal } }
    @Test func NC013_neutral() { run("NC-013", style: .standard) { $0.expected_neutral } }

    @Test func NC014_casual() { run("NC-014", style: .casual) { $0.expected_casual } }
    @Test func NC014_formal() { run("NC-014", style: .formal) { $0.expected_formal } }
    @Test func NC014_neutral() { run("NC-014", style: .standard) { $0.expected_neutral } }

    @Test func NC015_casual() { run("NC-015", style: .casual) { $0.expected_casual } }
    @Test func NC015_formal() { run("NC-015", style: .formal) { $0.expected_formal } }
    @Test func NC015_neutral() { run("NC-015", style: .standard) { $0.expected_neutral } }

    @Test func NC016_casual() { run("NC-016", style: .casual) { $0.expected_casual } }
    @Test func NC016_formal() { run("NC-016", style: .formal) { $0.expected_formal } }
    @Test func NC016_neutral() { run("NC-016", style: .standard) { $0.expected_neutral } }

    @Test func NC017_casual() { run("NC-017", style: .casual) { $0.expected_casual } }
    @Test func NC017_formal() { run("NC-017", style: .formal) { $0.expected_formal } }
    @Test func NC017_neutral() { run("NC-017", style: .standard) { $0.expected_neutral } }

    @Test func NC018_casual() { run("NC-018", style: .casual) { $0.expected_casual } }
    @Test func NC018_formal() { run("NC-018", style: .formal) { $0.expected_formal } }
    @Test func NC018_neutral() { run("NC-018", style: .standard) { $0.expected_neutral } }

    // MARK: - Capitalization

    @Test func CAP001_casual() { run("CAP-001", style: .casual) { $0.expected_casual } }
    @Test func CAP001_formal() { run("CAP-001", style: .formal) { $0.expected_formal } }
    @Test func CAP001_neutral() { run("CAP-001", style: .standard) { $0.expected_neutral } }

    @Test func CAP002_casual() { run("CAP-002", style: .casual) { $0.expected_casual } }
    @Test func CAP002_formal() { run("CAP-002", style: .formal) { $0.expected_formal } }
    @Test func CAP002_neutral() { run("CAP-002", style: .standard) { $0.expected_neutral } }

    @Test func CAP003_casual() { run("CAP-003", style: .casual) { $0.expected_casual } }
    @Test func CAP003_formal() { run("CAP-003", style: .formal) { $0.expected_formal } }
    @Test func CAP003_neutral() { run("CAP-003", style: .standard) { $0.expected_neutral } }

    @Test func CAP004_casual() { run("CAP-004", style: .casual) { $0.expected_casual } }
    @Test func CAP004_formal() { run("CAP-004", style: .formal) { $0.expected_formal } }
    @Test func CAP004_neutral() { run("CAP-004", style: .standard) { $0.expected_neutral } }

    @Test func CAP005_casual() { run("CAP-005", style: .casual) { $0.expected_casual } }
    @Test func CAP005_formal() { run("CAP-005", style: .formal) { $0.expected_formal } }
    @Test func CAP005_neutral() { run("CAP-005", style: .standard) { $0.expected_neutral } }

    @Test func CAP006_casual() { run("CAP-006", style: .casual) { $0.expected_casual } }
    @Test func CAP006_formal() { run("CAP-006", style: .formal) { $0.expected_formal } }
    @Test func CAP006_neutral() { run("CAP-006", style: .standard) { $0.expected_neutral } }

    // MARK: - List Detection

    @Test func LIST001_casual() { run("LIST-001", style: .casual) { $0.expected_casual } }
    @Test func LIST001_formal() { run("LIST-001", style: .formal) { $0.expected_formal } }
    @Test func LIST001_neutral() { run("LIST-001", style: .standard) { $0.expected_neutral } }

    @Test func LIST002_casual() { run("LIST-002", style: .casual) { $0.expected_casual } }
    @Test func LIST002_formal() { run("LIST-002", style: .formal) { $0.expected_formal } }
    @Test func LIST002_neutral() { run("LIST-002", style: .standard) { $0.expected_neutral } }

    @Test func LIST003_casual() { run("LIST-003", style: .casual) { $0.expected_casual } }
    @Test func LIST003_formal() { run("LIST-003", style: .formal) { $0.expected_formal } }
    @Test func LIST003_neutral() { run("LIST-003", style: .standard) { $0.expected_neutral } }

    @Test func LIST004_casual() { run("LIST-004", style: .casual) { $0.expected_casual } }
    @Test func LIST004_formal() { run("LIST-004", style: .formal) { $0.expected_formal } }
    @Test func LIST004_neutral() { run("LIST-004", style: .standard) { $0.expected_neutral } }

    @Test func LIST005_casual() { run("LIST-005", style: .casual) { $0.expected_casual } }
    @Test func LIST005_formal() { run("LIST-005", style: .formal) { $0.expected_formal } }
    @Test func LIST005_neutral() { run("LIST-005", style: .standard) { $0.expected_neutral } }

    // MARK: - Style Adaptation

    @Test func STYLEC001_casual() { run("STYLE-C-001", style: .casual) { $0.expected_casual } }
    @Test func STYLEC001_formal() { run("STYLE-C-001", style: .formal) { $0.expected_formal } }
    @Test func STYLEC001_neutral() { run("STYLE-C-001", style: .standard) { $0.expected_neutral } }

    @Test func STYLEC002_casual() { run("STYLE-C-002", style: .casual) { $0.expected_casual } }
    @Test func STYLEC002_formal() { run("STYLE-C-002", style: .formal) { $0.expected_formal } }
    @Test func STYLEC002_neutral() { run("STYLE-C-002", style: .standard) { $0.expected_neutral } }

    @Test func STYLEC003_casual() { run("STYLE-C-003", style: .casual) { $0.expected_casual } }
    @Test func STYLEC003_formal() { run("STYLE-C-003", style: .formal) { $0.expected_formal } }
    @Test func STYLEC003_neutral() { run("STYLE-C-003", style: .standard) { $0.expected_neutral } }

    @Test func STYLEF001_casual() { run("STYLE-F-001", style: .casual) { $0.expected_casual } }
    @Test func STYLEF001_formal() { run("STYLE-F-001", style: .formal) { $0.expected_formal } }
    @Test func STYLEF001_neutral() { run("STYLE-F-001", style: .standard) { $0.expected_neutral } }

    @Test func STYLEF002_casual() { run("STYLE-F-002", style: .casual) { $0.expected_casual } }
    @Test func STYLEF002_formal() { run("STYLE-F-002", style: .formal) { $0.expected_formal } }
    @Test func STYLEF002_neutral() { run("STYLE-F-002", style: .standard) { $0.expected_neutral } }

    @Test func STYLEF003_casual() { run("STYLE-F-003", style: .casual) { $0.expected_casual } }
    @Test func STYLEF003_formal() { run("STYLE-F-003", style: .formal) { $0.expected_formal } }
    @Test func STYLEF003_neutral() { run("STYLE-F-003", style: .standard) { $0.expected_neutral } }

    // MARK: - Edge Cases

    @Test func EDGE001_casual() { run("EDGE-001", style: .casual) { $0.expected_casual } }
    @Test func EDGE001_formal() { run("EDGE-001", style: .formal) { $0.expected_formal } }
    @Test func EDGE001_neutral() { run("EDGE-001", style: .standard) { $0.expected_neutral } }

    @Test func EDGE002_casual() { run("EDGE-002", style: .casual) { $0.expected_casual } }
    @Test func EDGE002_formal() { run("EDGE-002", style: .formal) { $0.expected_formal } }
    @Test func EDGE002_neutral() { run("EDGE-002", style: .standard) { $0.expected_neutral } }

    @Test func EDGE003_casual() { run("EDGE-003", style: .casual) { $0.expected_casual } }
    @Test func EDGE003_formal() { run("EDGE-003", style: .formal) { $0.expected_formal } }
    @Test func EDGE003_neutral() { run("EDGE-003", style: .standard) { $0.expected_neutral } }

    @Test func EDGE004_casual() { run("EDGE-004", style: .casual) { $0.expected_casual } }
    @Test func EDGE004_formal() { run("EDGE-004", style: .formal) { $0.expected_formal } }
    @Test func EDGE004_neutral() { run("EDGE-004", style: .standard) { $0.expected_neutral } }

    @Test func EDGE005_casual() { run("EDGE-005", style: .casual) { $0.expected_casual } }
    @Test func EDGE005_formal() { run("EDGE-005", style: .formal) { $0.expected_formal } }
    @Test func EDGE005_neutral() { run("EDGE-005", style: .standard) { $0.expected_neutral } }

    @Test func EDGE006_casual() { run("EDGE-006", style: .casual) { $0.expected_casual } }
    @Test func EDGE006_formal() { run("EDGE-006", style: .formal) { $0.expected_formal } }
    @Test func EDGE006_neutral() { run("EDGE-006", style: .standard) { $0.expected_neutral } }

    @Test func EDGE007_casual() { run("EDGE-007", style: .casual) { $0.expected_casual } }
    @Test func EDGE007_formal() { run("EDGE-007", style: .formal) { $0.expected_formal } }
    @Test func EDGE007_neutral() { run("EDGE-007", style: .standard) { $0.expected_neutral } }

    @Test func EDGE008_casual() { run("EDGE-008", style: .casual) { $0.expected_casual } }
    @Test func EDGE008_formal() { run("EDGE-008", style: .formal) { $0.expected_formal } }
    @Test func EDGE008_neutral() { run("EDGE-008", style: .standard) { $0.expected_neutral } }

    @Test func EDGE009_casual() { run("EDGE-009", style: .casual) { $0.expected_casual } }
    @Test func EDGE009_formal() { run("EDGE-009", style: .formal) { $0.expected_formal } }
    @Test func EDGE009_neutral() { run("EDGE-009", style: .standard) { $0.expected_neutral } }

    @Test func EDGE010_casual() { run("EDGE-010", style: .casual) { $0.expected_casual } }
    @Test func EDGE010_formal() { run("EDGE-010", style: .formal) { $0.expected_formal } }
    @Test func EDGE010_neutral() { run("EDGE-010", style: .standard) { $0.expected_neutral } }

    // MARK: - Stress Tests

    @Test func STRESS001_casual() { run("STRESS-001", style: .casual) { $0.expected_casual } }
    @Test func STRESS001_formal() { run("STRESS-001", style: .formal) { $0.expected_formal } }
    @Test func STRESS001_neutral() { run("STRESS-001", style: .standard) { $0.expected_neutral } }

    @Test func STRESS002_casual() { run("STRESS-002", style: .casual) { $0.expected_casual } }
    @Test func STRESS002_formal() { run("STRESS-002", style: .formal) { $0.expected_formal } }
    @Test func STRESS002_neutral() { run("STRESS-002", style: .standard) { $0.expected_neutral } }

    @Test func STRESS003_casual() { run("STRESS-003", style: .casual) { $0.expected_casual } }
    @Test func STRESS003_formal() { run("STRESS-003", style: .formal) { $0.expected_formal } }
    @Test func STRESS003_neutral() { run("STRESS-003", style: .standard) { $0.expected_neutral } }

    @Test func STRESS004_casual() { run("STRESS-004", style: .casual) { $0.expected_casual } }
    @Test func STRESS004_formal() { run("STRESS-004", style: .formal) { $0.expected_formal } }
    @Test func STRESS004_neutral() { run("STRESS-004", style: .standard) { $0.expected_neutral } }

    // MARK: - End-to-End

    @Test func E2E001_casual() { run("E2E-001", style: .casual) { $0.expected_casual } }
    @Test func E2E001_formal() { run("E2E-001", style: .formal) { $0.expected_formal } }
    @Test func E2E001_neutral() { run("E2E-001", style: .standard) { $0.expected_neutral } }

    @Test func E2E002_casual() { run("E2E-002", style: .casual) { $0.expected_casual } }
    @Test func E2E002_formal() { run("E2E-002", style: .formal) { $0.expected_formal } }
    @Test func E2E002_neutral() { run("E2E-002", style: .standard) { $0.expected_neutral } }

    @Test func E2E003_casual() { run("E2E-003", style: .casual) { $0.expected_casual } }
    @Test func E2E003_formal() { run("E2E-003", style: .formal) { $0.expected_formal } }
    @Test func E2E003_neutral() { run("E2E-003", style: .standard) { $0.expected_neutral } }

    @Test func E2E004_casual() { run("E2E-004", style: .casual) { $0.expected_casual } }
    @Test func E2E004_formal() { run("E2E-004", style: .formal) { $0.expected_formal } }
    @Test func E2E004_neutral() { run("E2E-004", style: .standard) { $0.expected_neutral } }

    @Test func E2E005_casual() { run("E2E-005", style: .casual) { $0.expected_casual } }
    @Test func E2E005_formal() { run("E2E-005", style: .formal) { $0.expected_formal } }
    @Test func E2E005_neutral() { run("E2E-005", style: .standard) { $0.expected_neutral } }

    @Test func E2E006_casual() { run("E2E-006", style: .casual) { $0.expected_casual } }
    @Test func E2E006_formal() { run("E2E-006", style: .formal) { $0.expected_formal } }
    @Test func E2E006_neutral() { run("E2E-006", style: .standard) { $0.expected_neutral } }

    @Test func E2E007_casual() { run("E2E-007", style: .casual) { $0.expected_casual } }
    @Test func E2E007_formal() { run("E2E-007", style: .formal) { $0.expected_formal } }
    @Test func E2E007_neutral() { run("E2E-007", style: .standard) { $0.expected_neutral } }

    @Test func E2E008_casual() { run("E2E-008", style: .casual) { $0.expected_casual } }
    @Test func E2E008_formal() { run("E2E-008", style: .formal) { $0.expected_formal } }
    @Test func E2E008_neutral() { run("E2E-008", style: .standard) { $0.expected_neutral } }

    @Test func E2E009_casual() { run("E2E-009", style: .casual) { $0.expected_casual } }
    @Test func E2E009_formal() { run("E2E-009", style: .formal) { $0.expected_formal } }
    @Test func E2E009_neutral() { run("E2E-009", style: .standard) { $0.expected_neutral } }

    @Test func E2E010_casual() { run("E2E-010", style: .casual) { $0.expected_casual } }
    @Test func E2E010_formal() { run("E2E-010", style: .formal) { $0.expected_formal } }
    @Test func E2E010_neutral() { run("E2E-010", style: .standard) { $0.expected_neutral } }

    @Test func E2E011_casual() { run("E2E-011", style: .casual) { $0.expected_casual } }
    @Test func E2E011_formal() { run("E2E-011", style: .formal) { $0.expected_formal } }
    @Test func E2E011_neutral() { run("E2E-011", style: .standard) { $0.expected_neutral } }

    @Test func E2E012_casual() { run("E2E-012", style: .casual) { $0.expected_casual } }
    @Test func E2E012_formal() { run("E2E-012", style: .formal) { $0.expected_formal } }
    @Test func E2E012_neutral() { run("E2E-012", style: .standard) { $0.expected_neutral } }

    @Test func E2E013_casual() { run("E2E-013", style: .casual) { $0.expected_casual } }
    @Test func E2E013_formal() { run("E2E-013", style: .formal) { $0.expected_formal } }
    @Test func E2E013_neutral() { run("E2E-013", style: .standard) { $0.expected_neutral } }

    @Test func E2E014_casual() { run("E2E-014", style: .casual) { $0.expected_casual } }
    @Test func E2E014_formal() { run("E2E-014", style: .formal) { $0.expected_formal } }
    @Test func E2E014_neutral() { run("E2E-014", style: .standard) { $0.expected_neutral } }

    @Test func E2E015_casual() { run("E2E-015", style: .casual) { $0.expected_casual } }
    @Test func E2E015_formal() { run("E2E-015", style: .formal) { $0.expected_formal } }
    @Test func E2E015_neutral() { run("E2E-015", style: .standard) { $0.expected_neutral } }

    // MARK: - Real World

    @Test func REAL001_casual() { run("REAL-001", style: .casual) { $0.expected_casual } }
    @Test func REAL001_formal() { run("REAL-001", style: .formal) { $0.expected_formal } }
    @Test func REAL001_neutral() { run("REAL-001", style: .standard) { $0.expected_neutral } }

    @Test func REAL002_casual() { run("REAL-002", style: .casual) { $0.expected_casual } }
    @Test func REAL002_formal() { run("REAL-002", style: .formal) { $0.expected_formal } }
    @Test func REAL002_neutral() { run("REAL-002", style: .standard) { $0.expected_neutral } }

    @Test func REAL003_casual() { run("REAL-003", style: .casual) { $0.expected_casual } }
    @Test func REAL003_formal() { run("REAL-003", style: .formal) { $0.expected_formal } }
    @Test func REAL003_neutral() { run("REAL-003", style: .standard) { $0.expected_neutral } }

    @Test func REAL004_casual() { run("REAL-004", style: .casual) { $0.expected_casual } }
    @Test func REAL004_formal() { run("REAL-004", style: .formal) { $0.expected_formal } }
    @Test func REAL004_neutral() { run("REAL-004", style: .standard) { $0.expected_neutral } }

    @Test func REAL005_casual() { run("REAL-005", style: .casual) { $0.expected_casual } }
    @Test func REAL005_formal() { run("REAL-005", style: .formal) { $0.expected_formal } }
    @Test func REAL005_neutral() { run("REAL-005", style: .standard) { $0.expected_neutral } }

    @Test func REAL006_casual() { run("REAL-006", style: .casual) { $0.expected_casual } }
    @Test func REAL006_formal() { run("REAL-006", style: .formal) { $0.expected_formal } }
    @Test func REAL006_neutral() { run("REAL-006", style: .standard) { $0.expected_neutral } }
}
