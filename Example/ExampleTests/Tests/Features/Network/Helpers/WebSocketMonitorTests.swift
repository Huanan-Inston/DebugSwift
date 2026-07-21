//
//  WebSocketMonitorTests.swift
//  DebugSwift
//

import XCTest
@testable import DebugSwift

final class WebSocketMonitorTests: XCTestCase {
    func testReceiveSwizzleKeepsOriginalHandlerAliveUntilForwarded() {
        WebSocketMonitor.shared.swizzleReceiveMessage(in: MockWebSocketTask.self)

        let task = MockWebSocketTask()
        let cancellation = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        let cancellationExpectation = expectation(description: "Cancellation handler forwarded")

        registerReceiveHandler(on: task) { message, error in
            XCTAssertNil(message)
            XCTAssertEqual(error, cancellation)
            cancellationExpectation.fulfill()
        }

        task.complete(message: nil, error: cancellation)

        let message = NSObject()
        let messageExpectation = expectation(description: "Message handler forwarded")

        registerReceiveHandler(on: task) { receivedMessage, error in
            XCTAssertTrue(receivedMessage === message)
            XCTAssertNil(error)
            messageExpectation.fulfill()
        }

        task.complete(message: message, error: nil)

        wait(for: [cancellationExpectation, messageExpectation], timeout: 1)
    }

    @inline(never)
    private func registerReceiveHandler(
        on task: MockWebSocketTask,
        completionHandler: @escaping (AnyObject?, NSError?) -> Void
    ) {
        task.receiveMessage(completionHandler: completionHandler)
    }
}

private final class MockWebSocketTask: NSObject {
    private var completionHandler: ((AnyObject?, NSError?) -> Void)?

    @objc(receiveMessageWithCompletionHandler:)
    dynamic func receiveMessage(
        completionHandler: @escaping (AnyObject?, NSError?) -> Void
    ) {
        self.completionHandler = completionHandler
    }

    func complete(message: AnyObject?, error: NSError?) {
        completionHandler?(message, error)
        completionHandler = nil
    }
}
