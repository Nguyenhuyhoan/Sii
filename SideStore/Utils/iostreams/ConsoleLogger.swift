
//
//  ConsoleLogger.swift
//  SideStore
//
//  Created by Magesh K on 25/11/24.
//  Copyright © 2024 SideStore. All rights reserved.
//

import Foundation

protocol ConsoleLogger{
    func startCapturing()
    func stopCapturing()
}

public class AbstractConsoleLogger<T: OutputStream>: ConsoleLogger{
    var outPipe: Pipe?
    var errPipe: Pipe?
    
    var outputHandle: FileHandle?
    var errorHandle:  FileHandle?
    
    var originalStdout: Int32?
    var originalStderr: Int32?
    
    let ostream: T
    
    let writeQueue = DispatchQueue(label: "async-write-queue")
    
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
        // ĐÃ TẮT HOÀN TOÀN: Không tạo Pipe, không dup2, không tắt bộ đệm setvbuf(_IONBF)
        // Giúp giải phóng 100% gánh nặng I/O và CPU khi các thư viện C/Rust in log.
        return
    }

    let shutdownLock = NSLock()

    func writeData(_ data: Data) throws {
        // Không làm gì cả
    }

    func stopCapturing() {
        // Không làm gì cả vì chưa bao giờ capture
    }
}

public class UnBufferedConsoleLogger<T: OutputStream>: AbstractConsoleLogger<T> {
    required override init(stream: T) {
        try! super.init(stream: stream)
    }
    
    override func writeData(_ data: Data) throws {
        // ĐÃ TẮT HOÀN TOÀN GHI LOG KHÔNG BỘ ĐỆM XUỐNG Ổ CỨNG
    }
}

public class BufferedConsoleLogger<T: OutputStream>: AbstractConsoleLogger<T> {
    private let maxBufferSize: Int
    
    required init(stream: T, bufferSize: Int = 1024) {
        self.maxBufferSize = bufferSize
        try! super.init(stream: stream)
    }
    
    override func writeData(_ data: Data) throws {
        // ĐÃ TẮT HOÀN TOÀN GHI LOG XUỐNG Ổ CỨNG
    }

    override func stopCapturing() {
        super.stopCapturing()
    }
}
