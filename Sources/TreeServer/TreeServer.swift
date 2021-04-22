import Foundation
import HyperSwift
import Network

public enum SiteNode {
	case file(name: String, type: String)
	case literal(text: String, type: String)
	indirect case subDir(default: SiteNode, subNodes: Dictionary<String, SiteNode>)
	case redirect(toURL: String)
	case special(resolver: (Request?, NWConnection) -> Response)
	indirect case specialSubDir(default: SiteNode, resolver: (Request?, NWConnection) -> Response)
}

public func getEndNodeValue(node: SiteNode, request: Request, connection: NWConnection, errorHandler: (Int, String) -> Response) -> Response {
	switch node {
	case .file(name: let name, type: let type):
		let fileContent = try? Data(contentsOf: URL(fileURLWithPath: name))
		return Response(code: 200, reason: "Success", headers: ["Content-Type": type], body: fileContent)
	case .redirect(toURL: let redirectURL):
		return Response(code: 301, reason: "Moved permanently", headers: ["Location": redirectURL], body: nil)
	case .special(resolver: let resolver):
		return resolver(request, connection)
	case .subDir(default: let deflt, subNodes: _):
		return getEndNodeValue(node: deflt, request: request, connection: connection, errorHandler: errorHandler)
	case .literal(text: let text, type: let cType):
		return Response(code: 200, reason: "Success", headers: ["Content-Type": cType], body: text.data(using: .utf8))
	case .specialSubDir(default: let deflt, resolver: _):
		return getEndNodeValue(node: deflt, request: request, connection: connection, errorHandler: errorHandler)
	}
}

public func evaluateRequest(request: Request, baseNode: SiteNode, errorHandler: (Int, String) -> Response, connection: NWConnection) -> Response {
	if request.parsedURL == nil {
		return errorHandler(400, "invalid url")
	}
	
	var currentNode = baseNode
	for nodeName in request.parsedURL!.path {
		switch currentNode {
		case .subDir(default: _, subNodes: let subnodes):
			let nextNode = subnodes[nodeName]
			if nextNode == nil {
				return errorHandler(404, "page doesn't exist")
			}
			currentNode = nextNode!
		case .specialSubDir(default: _, resolver: let resolver):
			return resolver(request, connection)
		default:
			return errorHandler(404, "not a directory")
		}
	}
	
	return getEndNodeValue(node: currentNode, request: request, connection: connection, errorHandler: errorHandler)
}
