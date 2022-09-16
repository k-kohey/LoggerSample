//
//  RegularlyPollingSchedulerTests.swift
//
//
//  Created by k-kohey on 2021/12/06.
//

import Foundation
@testable import Parchment
@testable import ParchmentDefault
import XCTest

final class EventQueueMock: TrackingEventBuffer {
    private var records: [BufferRecord] = []

    func save(_ e: [BufferRecord]) {
        records += e
    }

    func load(limit: Int64) -> [BufferRecord] {
        let count = limit > 0 ? Int(limit) : records.count
        return (0 ..< min(count, records.count)).reduce([]) { result, _ in
            result + [dequeue()].compactMap { $0 }
        }
    }

    func count() -> Int {
        records.count
    }

    private func dequeue() -> BufferRecord? {
        defer {
            if !records.isEmpty {
                records.removeFirst()
            }
        }
        return records.first
    }
}

class RegularlyPollingSchedulerTests: XCTestCase {
    func testSchedule() throws {
        let scheduler = RegularlyPollingScheduler(timeInterval: 0.1)
        let buffer = EventQueueMock()
        let event = TrackingEvent(eventName: "hoge", parameters: [:])

        Task {
            for try await result in await scheduler.schedule(with: .init(buffer)) {
                XCTAssertEqual(event.eventName, result.first?.eventName)
                XCTAssertTrue(NSDictionary(dictionary: event.parameters).isEqual(to: result.first?.parameters ?? [:]))
            }
        }
        buffer.save([.init(destination: "hoge", event: event, timestamp: Date())])
    }
}
