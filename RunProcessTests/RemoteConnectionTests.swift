//
//  RemoteConnectionTests.swift
//  RunProcessTests
//
//  Created by Haoran on 2026/11/7.
//

import XCTest
import RemoteLinkKit
import RemoteProcessProtocol

#if BETA
@testable import RunProcess_Preview
#else
@testable import RunProcess
#endif

final class RemoteConnectionTests: XCTestCase {

    // 纯内存的回环传输，完全不依赖真实网络
    private final class LoopbackTransport: RemoteConnection, @unchecked Sendable {
        var state: ConnectionState = .connected
        var onStateChange: (@Sendable (ConnectionState) -> Void)?
        var onReceive: (@Sendable (Data) -> Void)?
        weak var peer: LoopbackTransport?
        
        func connect() async throws {}
        func send(_ data: Data) async throws {
            peer?.onReceive?(data)
        }
        func close() {}
    }

    func testEncryptedHandshakeAndExecution() async throws {
        let clientTransport = LoopbackTransport()
        let serverTransport = LoopbackTransport()
        clientTransport.peer = serverTransport
        serverTransport.peer = clientTransport
        
        // 1. 模拟客户端和 Open 的 SecureChannel
        let clientCipher = try AESGCMCipher(key: Data(repeating: 0x11, count: 32))
        let clientChannel = SecureChannel(
            transport: clientTransport,
            cipher: clientCipher,
            cipherId: AESGCMCipher.cipherId,
            isClient: true
        )
        
        // 2. 模拟服务端和 Open 的 SecureChannel
        let serverCipher = try AESGCMCipher(key: Data(repeating: 0x11, count: 32))
        let serverChannel = SecureChannel(
            transport: serverTransport,
            cipher: serverCipher,
            cipherId: AESGCMCipher.cipherId,
            isClient: false
        )
        
        await clientChannel.start()
        await serverChannel.start()
        
        // 3. 测试：客户端发送命令，服务端接收
        let expectation = XCTestExpectation(description: "Server received exec command")
        let commandId = UUID().uuidString
        let command = "echo 'RunProcess Test'"
        
        await serverChannel.setOnClientMessage { msg in
            if case .exec(let id, let cmd, _) = msg {
                XCTAssertEqual(id, commandId)
                XCTAssertEqual(cmd, command)
                
                // 服务端收到命令后，模拟执行并回传 output 和 done
                Task {
                    try await serverChannel.send(.output(id: id, stream: .stdout, data: Data("RunProcess Test\n".utf8)))
                    try await serverChannel.send(.done(id: id, exit: 0, cwd: "/"))
                }
                expectation.fulfill()
            }
        }
        
        // 4. 客户端发送命令
        try await clientChannel.send(.exec(id: commandId, cmd: command, timeout: 5.0))
        
        // 等待服务端接收
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // 5. 验证客户端是否能成功解密接收到的返回数据
        let clientExpectation = XCTestExpectation(description: "Client received output")
        await clientChannel.setOnServerMessage { msg in
            switch msg {
            case .output(_, _, let data):
                XCTAssertEqual(String(data: data, encoding: .utf8), "RunProcess Test\n")
                clientExpectation.fulfill()
            case .done(_, let exit, _):
                XCTAssertEqual(exit, 0)
            default:
                break
            }
        }
        
        // 等待客户端处理完所有消息
        await fulfillment(of: [clientExpectation], timeout: 2.0)
    }
}
