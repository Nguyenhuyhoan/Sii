// SideStore/Utils/iostreams/ConsoleLogger.swift


//
//  ConsoleLogger.swift
//  SideStore
//
//  Created by Magesh K on 25/11/24.
//  Copyright © 2024 SideStore. All rights reserved.
//

import Foundation

protocol ConsoleLogger {
    func startCapturing()
    func stopCapturing()
}

public class AbstractConsoleLogger<T: OutputStream>: ConsoleLogger {
    let ostream: T

    public init(stream: T) throws {
        if Self.self === AbstractConsoleLogger.self {
            throw AbstractClassError.abstractInitializerInvoked
        }
        self.ostream = stream
    }

    deinit {
        stopCapturing()
    }

    public func startCapturing() {
        // Đã tắt việc chặn bắt stdout/stderr để chống nóng CPU
    }

    func writeData(_ data: Data) throws {}

    public func stopCapturing() {
        ostream.close()
    }
}

public class UnBufferedConsoleLogger<T: OutputStream>: AbstractConsoleLogger<T> {
    required override init(stream: T) {
        try! super.init(stream: stream)
    }

    override func writeData(_ data: Data) throws {}
}

public class BufferedConsoleLogger<T: OutputStream>: AbstractConsoleLogger<T> {
    required init(stream: T, bufferSize: Int = 4096) {
        try! super.init(stream: stream)
    }

    override func writeData(_ data: Data) throws {}

    public override func stopCapturing() {
        super.stopCapturing()
    }
}
