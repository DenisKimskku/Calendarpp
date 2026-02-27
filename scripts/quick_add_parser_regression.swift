import Foundation

private struct ParserCase {
    let name: String
    let input: String
    let expectedTitle: String
    let expectedLocation: String?
    let expectedStartHour: Int
    let expectedStartMinute: Int
    let expectedDurationMinutes: Int
}

private let calendar = Calendar.current
private var failures: [String] = []

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        failures.append(message)
    }
}

private func normalized(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
}

private func runCase(_ parserCase: ParserCase, parser: SmartEventParser) {
    print("[case] \(parserCase.name)")

    guard let parsed = parser.parse(parserCase.input) else {
        failures.append("Parse failed for input: \(parserCase.input)")
        return
    }

    assertCondition(
        normalized(parsed.title) == normalized(parserCase.expectedTitle),
        "Title mismatch for '\(parserCase.input)'. Expected '\(parserCase.expectedTitle)', got '\(parsed.title)'."
    )

    if let expectedLocation = parserCase.expectedLocation {
        assertCondition(
            normalized(parsed.location ?? "") == normalized(expectedLocation),
            "Location mismatch for '\(parserCase.input)'. Expected '\(expectedLocation)', got '\(parsed.location ?? "nil")'."
        )
    } else {
        assertCondition(
            parsed.location == nil || normalized(parsed.location ?? "").isEmpty,
            "Location should be empty for '\(parserCase.input)', got '\(parsed.location ?? "nil")'."
        )
    }

    let startHour = calendar.component(.hour, from: parsed.startDate)
    let startMinute = calendar.component(.minute, from: parsed.startDate)
    assertCondition(
        startHour == parserCase.expectedStartHour && startMinute == parserCase.expectedStartMinute,
        "Start time mismatch for '\(parserCase.input)'. Expected \(parserCase.expectedStartHour):\(String(format: "%02d", parserCase.expectedStartMinute)), got \(startHour):\(String(format: "%02d", startMinute))."
    )

    let durationMinutes = Int(parsed.endDate.timeIntervalSince(parsed.startDate) / 60)
    assertCondition(
        durationMinutes == parserCase.expectedDurationMinutes,
        "Duration mismatch for '\(parserCase.input)'. Expected \(parserCase.expectedDurationMinutes)m, got \(durationMinutes)m."
    )
}

@main
struct QuickAddParserRegressionMain {
    static func main() {
        let parser = SmartEventParser.shared
        let cases: [ParserCase] = [
            ParserCase(
                name: "numeric range with location",
                input: "meeting with Kevin in lab from 4pm to 6pm",
                expectedTitle: "Meeting with Kevin",
                expectedLocation: "lab",
                expectedStartHour: 16,
                expectedStartMinute: 0,
                expectedDurationMinutes: 120
            ),
            ParserCase(
                name: "starting from range with location",
                input: "meeting with Kevin in lab starting from 4pm to 6pm",
                expectedTitle: "Meeting with Kevin",
                expectedLocation: "lab",
                expectedStartHour: 16,
                expectedStartMinute: 0,
                expectedDurationMinutes: 120
            ),
            ParserCase(
                name: "worded meridiem range",
                input: "meeting with Kevin at four pm till six pm",
                expectedTitle: "Meeting with Kevin",
                expectedLocation: nil,
                expectedStartHour: 16,
                expectedStartMinute: 0,
                expectedDurationMinutes: 120
            ),
            ParserCase(
                name: "single-time defaults to 60 minutes",
                input: "lunch tomorrow at 1pm",
                expectedTitle: "Lunch",
                expectedLocation: nil,
                expectedStartHour: 13,
                expectedStartMinute: 0,
                expectedDurationMinutes: 60
            )
        ]

        for parserCase in cases {
            runCase(parserCase, parser: parser)
        }

        if failures.isEmpty {
            print("ALL QUICK ADD PARSER REGRESSION TESTS PASSED")
            exit(EXIT_SUCCESS)
        }

        print("QUICK ADD PARSER REGRESSION TESTS FAILED (\(failures.count))")
        for failure in failures {
            print("- \(failure)")
        }
        exit(EXIT_FAILURE)
    }
}
