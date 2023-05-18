//
//  Tracked.swift
//  
//
//  Created by Kohei Kawaguchi on 2023/05/17.
//

import Foundation

@propertyWrapper
public struct Tracked<Value: Sendable, ScopeValue: Sendable> {
    private let logger: LoggerBundler
    private let option: LoggerBundler.LoggingOption
    private var updatedCount = 0

    public var wrappedValue: Value {
        didSet {
            updatedCount += 1
            let value: any Sendable
            if let scope {
                value = wrappedValue[keyPath: scope]
            } else {
                value = wrappedValue
            }
            track(newValue: value)
        }
    }

    private func track(newValue: some Sendable) {
        let logger = logger
        let option = option
        let updatedCount = updatedCount
        let name = name
        Task(priority: .medium) {
            let parameters: [String: Sendable] = [
                "updaetd_value": newValue,
                "updated_count": updatedCount
            ]
            await logger.send(
                AnyLoggable(eventName: name, parameters: parameters),
                with: option
            )
        }
    }

    private let name: String
    private var scope: KeyPath<Value, ScopeValue>? = nil

    public init(
        wrappedValue: Value,
        name: String,
        with logger: LoggerBundler,
        option: LoggerBundler.LoggingOption = .init()
    )  where ScopeValue == Never {
        self.init(
            wrappedValue: wrappedValue, name: name, with: logger, scope: nil, option: option
        )
    }

    public init(
        wrappedValue: Value,
        name: String,
        with logger: LoggerBundler,
        scope: KeyPath<Value, ScopeValue>? = nil,
        option: LoggerBundler.LoggingOption = .init()
    ) {
        self.name = name
        self.logger = logger
        self.option = option
        self.scope = scope
        self.wrappedValue = wrappedValue
    }
}

#if canImport(SwiftUI)

import SwiftUI

public extension Binding {
    func erase<InnerType: Sendable, Scope: Sendable>() -> Binding<InnerType> where Value == Tracked<InnerType, Scope> {
        Binding<InnerType>(
            get: {
                wrappedValue.wrappedValue
            }, set: {
                wrappedValue.wrappedValue = $0
            })
    }
}

#endif
