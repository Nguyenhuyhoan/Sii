
// SideStore/Utils/iostreams/ ConsoleLogger.swift

//
//  ConsoleCapture.swift
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
    var outPipe: Pipe?
    var errPipe: Pipe?
    
    var outputHandle: FileHandle?
    var errorHandle:  FileHandle?
    
    var originalStdout: Int32?
    var originalStderr: Int32?
    
    let ostream: T
    
    let writeQueue = DispatchQueue(label: "async-write-queue", qos: .utility)
    
    public init(stream: T) throws {
        // Since swift doesn't support compile time abstract classes Instantiation checking,
        // we are using runtime check to prevent direct instantiation :(
        if Self.self === AbstractConsoleLogger.self {
            throw AbstractClassError.abstractInitializerInvoked
        }
        
        self.ostream = stream
    }
    
    deinit {
        stopCapturing()
    }
    
    public func startCapturing() {
        // if already initialized within current instance, bail out
        guard outPipe == nil, errPipe == nil else {
            return
        }
        
        // Create new pipes for stdout and stderr
        self.outPipe = Pipe()
        self.errPipe = Pipe()
        
        outputHandle = self.outPipe?.fileHandleForReading
        errorHandle = self.errPipe?.fileHandleForReading

        // Store original file descriptors
        originalStdout = dup(STDOUT_FILENO)
        originalStderr = dup(STDERR_FILENO)
        
        let redirectedOutStream = self.outPipe?.fileHandleForWriting.fileDescriptor ?? -1
        let redirectedErrStream = self.errPipe?.fileHandleForWriting.fileDescriptor ?? -1
        
        // Redirect stdout and stderr to our pipes
        dup2(redirectedOutStream, STDOUT_FILENO)
        dup2(redirectedErrStream, STDERR_FILENO)

        // Use line-buffering (_IOLBF) instead of unbuffered (_IONBF) to prevent high CPU syscall overhead
        setvbuf(stdout, nil, _IOLBF, 4096)
        setvbuf(stderr, nil, _IOLBF, 4096)
        
        // Setup readability handlers for raw data
        setupReadabilityHandler(for: outputHandle, isError: false)
        setupReadabilityHandler(for: errorHandle, isError: true)
    }

    let shutdownLock = NSLock()

    private func setupReadabilityHandler(for handle: FileHandle?, isError: Bool) {
        handle?.readabilityHandler = readHandler(isError: isError)
    }

    private func readHandler(isError: Bool) -> (FileHandle) -> Void {
        return { [weak self] fileHandle in
            // Lock first before touching anything
            self?.shutdownLock.lock()
            defer { self?.shutdownLock.unlock() }

            // Capture strong self *after* lock is acquired
            guard let self = self else {
                fileHandle.readabilityHandler = nil
                return
            }
            
            let handle = isError ? self.errorHandle : self.outputHandle
            
            // FIX 100% CPU SPIN-LOCK: If availableData is empty (EOF/Pipe closed),
            // we MUST nil out readabilityHandler immediately, otherwise libdispatch triggers it infinitely.
            guard let data = handle?.availableData, !data.isEmpty else {
                handle?.readabilityHandler = nil
                return
            }

            self.writeQueue.async {
                try? self.writeData(data)
            }

            // 2. Echo to original stdout/stderr if still valid
            guard let fd = isError ? self.originalStderr : self.originalStdout else {
                return
            }

            guard fcntl(fd, F_GETFD) != -1 else {
                return
            }

            data.withUnsafeBytes { rawBufferPointer in
                guard let base = rawBufferPointer.baseAddress else { return }
                var remaining = data.count
                var offset = 0
                let maxChunkSize = 16 * 1024 // 16 KB chunks

                // write in chunks, else will throw 'Result too large'
                while remaining > 0 {
                    let chunkSize = min(maxChunkSize, remaining)
                    let written = write(fd, base.advanced(by: offset), chunkSize)

                    if written < 0 {
                        break
                    }

                    remaining -= written
                    offset += written
                }
            }
        }
    }

    func writeData(_ data: Data) throws {
        throw AbstractClassError.abstractMethodInvoked
    }

    func stopCapturing() {
        shutdownLock.lock()
        defer { shutdownLock.unlock() }

        ostream.close()
        
        // Restore original stdout and stderr
        if let stdout = originalStdout, stdout != STDOUT_FILENO {
            dup2(stdout, STDOUT_FILENO)
            close(stdout)
        }
        if let stderr = originalStderr, stderr != STDERR_FILENO {
            dup2(stderr, STDERR_FILENO)
            close(stderr)
        }
        
        // Clean up
        outPipe?.fileHandleForReading.readabilityHandler = nil
        errPipe?.fileHandleForReading.readabilityHandler = nil
        outPipe = nil
        errPipe = nil
        outputHandle = nil
        errorHandle = nil
        originalStdout = nil
        originalStderr = nil
    }
}

public class UnBufferedConsoleLogger<T: OutputStream>: AbstractConsoleLogger<T> {

    required override init(stream: T) {
        try! super.init(stream: stream)
    }
    
    override func writeData(_ data: Data) throws {
        ostream.write(data)
    }
}

public class BufferedConsoleLogger<T: OutputStream>: AbstractConsoleLogger<T> {

    // Buffer size (bytes) and storage
    private let maxBufferSize: Int
    private var bufferedData = Data()
    
    required init(stream: T, bufferSize: Int = 4096) {
        self.maxBufferSize = bufferSize
        try! super.init(stream: stream)
    }
    
    override func writeData(_ data: Data) throws {
        // Append data to buffer
        self.bufferedData.append(data)
        
        // Check if the buffer is full and flush
        if self.bufferedData.count >= self.maxBufferSize {
            self.flushBuffer()
        }
    }
    
    private func flushBuffer() {
        guard !bufferedData.isEmpty else { return }
        // Write all buffered data to the stream
        ostream.write(bufferedData)
        bufferedData.removeAll(keepingCapacity: true)
    }

    override func stopCapturing() {
        // Flush buffer and close the file handles first
        writeQueue.sync {
            flushBuffer()
        }
        super.stopCapturing()
    }
}
