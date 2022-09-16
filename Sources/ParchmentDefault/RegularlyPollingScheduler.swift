//
//  RegularlyPollingScheduler.swift
//
//
//  Created by k-kohey on 2021/12/29.
//

import Foundation
import Parchment

public final class RegularlyPollingScheduler: BufferedEventFlushScheduler {
    public static let `default` = RegularlyPollingScheduler(timeInterval: 60)

    let timeInterval: TimeInterval
    let limitOnNumberOfEvent: Int

    var lastFlushedDate: Date = .init()

    private weak var timer: Timer?

    public init(
        timeInterval: TimeInterval,
        limitOnNumberOfEvent: Int = .max,
        dispatchQueue _: DispatchQueue? = nil
    ) {
        self.timeInterval = timeInterval
        self.limitOnNumberOfEvent = limitOnNumberOfEvent
    }

    public func schedule(with buffer: TrackingEventBufferAdapter) async -> AsyncThrowingStream<[BufferRecord], Error> {
        AsyncThrowingStream { continuation in
            let timer = Timer(fire: .init(), interval: 1, repeats: true) { _ in
                Task { [weak self] in
                    await self?.tick(with: buffer) {
                        continuation.yield($0)
                    }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    public func cancel() {
        timer?.invalidate()
    }

    private func tick(with buffer: TrackingEventBufferAdapter, didFlush: @escaping ([BufferRecord]) -> Void) async {
        guard await buffer.count() > 0 else { return }

        let flush = {
            let records = await buffer.load()

//            console()?.log("✨ Flush \(records.count) event")
            didFlush(records)
        }

        let count = await buffer.count()
        if limitOnNumberOfEvent < count {
            await flush()
            return
        }

        let timeSinceLastFlush = abs(lastFlushedDate.timeIntervalSinceNow)
        if timeInterval < timeSinceLastFlush {
            await flush()
            lastFlushedDate = Date()
            return
        }
    }
}
