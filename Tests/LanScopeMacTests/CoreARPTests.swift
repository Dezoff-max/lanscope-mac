import Darwin
import Foundation
import XCTest
@testable import LanScopeMac

final class CoreARPTests: XCTestCase {
    func testDarwinCapturedRoutingMessageUsesFourByteSockaddrAlignment() throws {
        // Captured from NET_RT_FLAGS on arm64 macOS; addresses and runtime metrics
        // anonymized. Actual layout is header(92), IPv4(16), link(20), interface IPv4(16).
        // Eight-byte alignment incorrectly skips four bytes of the third sockaddr.
        let fixture = try XCTUnwrap(Data(base64Encoded: "kAAFBA8AAAAFBAIVIwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAgAAwAACAQAAAAAAAAAAFBIPAAYABgACAAAAAAEAAAAAAAAQAgAAwAACYwAAAAAAAAAA"))
        XCTAssertEqual(fixture.count, 144)
        XCTAssertEqual(ARPResolver().parseRoutingTable(Array(fixture), byteCount: fixture.count),
                       ["192.0.2.1": "02:00:00:00:00:01"])
    }

    func testDuplicateIPIsScopedToSelectedInterface() {
        let firstMAC: [UInt8] = [0, 1, 2, 3, 4, 5]
        let secondMAC: [UInt8] = [6, 7, 8, 9, 10, 11]
        let table = routingMessage(interfaceIndex: 4, mac: firstMAC)
            + routingMessage(interfaceIndex: 8, mac: secondMAC)
        let resolver = ARPResolver()
        XCTAssertEqual(resolver.parseRoutingTable(table, byteCount: table.count, interfaceIndex: 4),
                       ["192.168.1.1": "00:01:02:03:04:05"])
        XCTAssertEqual(resolver.parseRoutingTable(table, byteCount: table.count, interfaceIndex: 8),
                       ["192.168.1.1": "06:07:08:09:0A:0B"])
        XCTAssertTrue(resolver.parseRoutingTable(table, byteCount: table.count, interfaceIndex: 12).isEmpty)
    }

    func testCompactLinkAddressAndOversizedByteCountAreSafe() {
        let table = routingMessage(interfaceIndex: 4, mac: [0, 1, 2, 3, 4, 5])
        // A valid 14-byte sockaddr_dl is shorter than MemoryLayout<sockaddr_dl>.size.
        XCTAssertEqual(ARPResolver().parseRoutingTable(table, byteCount: table.count + 1024),
                       ["192.168.1.1": "00:01:02:03:04:05"])
    }

    func testTruncatedSocketAddressesAreRejected() {
        let resolver = ARPResolver()
        let complete = routingMessage(interfaceIndex: 4, mac: [0, 1, 2, 3, 4, 5])
        XCTAssertTrue(resolver.parseRoutingTable(Array(complete.dropLast()), byteCount: complete.count).isEmpty)
        var invalidLinkLength = complete
        invalidLinkLength[MemoryLayout<rt_msghdr>.size + 16] = 255
        XCTAssertTrue(resolver.parseRoutingTable(invalidLinkLength, byteCount: invalidLinkLength.count).isEmpty)
        var invalidLinkNameLength = complete
        invalidLinkNameLength[MemoryLayout<rt_msghdr>.size + 16 + 5] = 250
        XCTAssertTrue(resolver.parseRoutingTable(invalidLinkNameLength, byteCount: invalidLinkNameLength.count).isEmpty)
        var invalidIPLength = complete
        invalidIPLength[MemoryLayout<rt_msghdr>.size] = 8
        XCTAssertTrue(resolver.parseRoutingTable(invalidIPLength, byteCount: invalidIPLength.count).isEmpty)
    }

    func testUnknownSelectedInterfaceDoesNotReturnOtherInterfaces() {
        XCTAssertTrue(ARPResolver().resolvedIPv4Entries(interfaceName: "lanscope-no-such-interface").isEmpty)
    }

    func testLegacyResolverUsesProtocolDefault() {
        struct LegacyResolver: ARPResolving {
            func resolvedIPv4Entries() -> [String: String] { ["192.168.1.1": "00:01:02:03:04:05"] }
        }
        let resolver: ARPResolving = LegacyResolver()
        XCTAssertEqual(resolver.resolvedIPv4Entries(interfaceName: "en0"), resolver.resolvedIPv4Entries())
    }

    private func routingMessage(interfaceIndex: UInt16, mac: [UInt8]) -> [UInt8] {
        var header = rt_msghdr()
        header.rtm_msglen = UInt16(MemoryLayout<rt_msghdr>.size + 32)
        header.rtm_version = UInt8(RTM_VERSION)
        header.rtm_index = interfaceIndex
        header.rtm_addrs = Int32((1 << Int(RTAX_DST)) | (1 << Int(RTAX_GATEWAY)))
        let destination: [UInt8] = [16, UInt8(AF_INET), 0, 0, 192, 168, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]
        let gateway: [UInt8] = [14, UInt8(AF_LINK), 0, 0, 0, 0, 6, 0] + mac + [0, 0]
        return withUnsafeBytes(of: &header) { Array($0) } + destination + gateway
    }
}
