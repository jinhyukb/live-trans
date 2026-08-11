import Foundation
import CoreMedia

public enum CaptureWireMessageType: UInt8, Sendable {
    case format = 1
    case frame = 2
}

public enum CaptureWire {
    public static func encode(_ type: CaptureWireMessageType, payload: Data) -> Data {
        var data = Data()
        data.append(type.rawValue)
        var length = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
        data.append(payload)
        return data
    }
}

public struct CaptureWireParser: Sendable {
    private var buffer = Data()

    public mutating func append(_ data: Data, yield: (CaptureWireMessageType, Data) -> Void) {
        buffer.append(data)
        while true {
            guard buffer.count >= 5 else { return }
            let type = CaptureWireMessageType(rawValue: buffer[buffer.startIndex])
            let length = UInt32(buffer[buffer.index(buffer.startIndex, offsetBy: 1)])
                << 24
                | UInt32(buffer[buffer.index(buffer.startIndex, offsetBy: 2)]) << 16
                | UInt32(buffer[buffer.index(buffer.startIndex, offsetBy: 3)]) << 8
                | UInt32(buffer[buffer.index(buffer.startIndex, offsetBy: 4)])
            let payloadLength = Int(length)
            guard buffer.count >= 5 + payloadLength else { return }
            let payload = buffer.subdata(
                in: buffer.startIndex + 5 ..< buffer.startIndex + 5 + payloadLength
            )
            buffer.removeFirst(5 + payloadLength)
            if let type {
                yield(type, payload)
            }
        }
    }
}