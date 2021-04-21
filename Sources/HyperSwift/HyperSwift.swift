import Foundation
import Network
import SimpleServer

public enum HTTPMethod: String {
	case GET = "GET"
	case POST = "POST"
}

public struct Request {
	public let url: String
	public var parsedURL: (path: Array<String>, args: Dictionary<String, String>?)? {
		var args: Dictionary<String, String> = [:]
		let splitURL = self.url.split(separator: "?")
		if splitURL.count > 2 {
			return nil
		}
		var path: Array<String> = []
		for subString in splitURL[0].split(separator: "/") {
			path.append(String(subString))
		}
		if splitURL.count == 2 {
			for arg in splitURL[1].split(separator: "&") {
				let splitArg = arg.split(separator: "=")
				if splitArg.count != 2 {
					return nil
				} else {
					args[String(splitArg[0])] = String(splitArg[1])
				}
			}
			return (path: path, args: args)
		}
		return (path: path, args: nil)
	}
	public let method: HTTPMethod
	public let headers: Dictionary<String, String>
	public let body: Data?
	
	public init(url: String, headers: Dictionary<String, String>) {
		self.url = url
		self.method = .GET
		self.headers = headers
		self.body = nil
	}
	
	public init(url: String, method: HTTPMethod, headers: Dictionary<String, String>, body: Data?) {
		self.url = url
		self.method = method
		self.headers = headers
		self.body = body
	}
	
	public init?(data: Data?) {
		let requestString = String(data: data ?? Data(), encoding: .ascii)
		if requestString == nil {
			return nil
		}
		var requestList = requestString!.components(separatedBy: "\r\n").dropLast()
		while requestList.count < 2 {
			requestList.append("")
		}
		let requestLine = requestList[0].split(separator: " ")
		if requestLine.count != 3 || HTTPMethod(rawValue: String(requestLine[0])) == nil {
			return nil
		}
		self.method = HTTPMethod(rawValue: String(requestLine[0]))!
		self.url = String(requestLine[1])
		var finalHeaders: Dictionary<String, String> = [:]
		for line in requestList.dropFirst().dropLast() {
			let colonSplit = String(line).components(separatedBy: ": ")
			if colonSplit.count != 2 {
				return nil
			}
			finalHeaders[colonSplit[0]] = colonSplit[1]
		}
		self.headers = finalHeaders
		self.body = requestList.last?.data(using: .ascii)
	}
}

public struct Response {
	public let code: UInt
	public let reason: String
	public let headers: Dictionary<String, String>
	public let body: Data?
	
	public var dataRepresentation: Data {
		var res = "HTTP/1.1 \(String(self.code)) \(self.reason)\r\n"
		for header in headers.keys {
			res += "\(header): \(headers[header]!)\r\n"
		}
		res += "\r\n"
		
		return res.data(using: .ascii)!+(body ?? Data())
	}
	
	public init(code: UInt, reason: String, headers: Dictionary<String, String>, body: Data?) {
		self.code = code
		self.reason = reason
		self.headers = headers
		self.body = body
	}
}

public class HTTPServer: SimpleServer {
	public let httpRequestHandler: (Request?, NWConnection) -> Response?
	
	public init(requestHandler: @escaping (Request?, NWConnection) -> Response, port: Int) {
		self.httpRequestHandler = requestHandler
		let reqh: (NWConnection, Data?) -> (data: Data?, close: Bool) = {connection, data in
			return (data: requestHandler(Request(data: data), connection).dataRepresentation, close: true)
		}
		super.init(port: port, requestHandler: reqh)
	}
}
