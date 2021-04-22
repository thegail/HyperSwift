import Foundation
import HyperSwift
import Network

public enum SiteNode {
	case file(name: String, type: String)
	case literal(text: String, type: String)
	indirect case subDir(default: SiteNode, subNodes: Dictionary<String, SiteNode>)
	case redirect(toURL: String)
	case special(resolver: (Request?, NWConnection) -> Response)
}

public func getEndNodeValue(node: SiteNode, request: Request, connection: NWConnection) -> Response {
	switch node {
	case .file(name: let name, type: let type):
		let fileContent = try? Data(contentsOf: URL(fileURLWithPath: name))
		return Response(code: 200, reason: "Success", headers: ["Content-Type": type], body: fileContent)
	case .redirect(toURL: let redirectURL):
		return Response(code: 301, reason: "Moved permanently", headers: ["Location": redirectURL], body: nil)
	case .special(resolver: let resolver):
		return resolver(request, connection)
	case .subDir(default: let deflt, subNodes: _):
		return getEndNodeValue(node: deflt, request: request, connection: connection)
	case .literal(text: let text, type: let cType):
		return Response(code: 200, reason: "Success", headers: ["Content-Type": cType], body: text.data(using: .utf8))
	}
}

public func evaluateRequest(request: Request, baseNode: SiteNode, errorHandler: (Int, String) -> Response, connection: NWConnection) -> Response {
	if request.parsedURL == nil {
		return errorHandler(400, "Bad request (invalid URL)")
	}
	
	var currentNode = baseNode
	for nodeName in request.parsedURL!.path {
		switch currentNode {
		case .subDir(default: _, subNodes: let subnodes):
			let nextNode = subnodes[nodeName]
			if nextNode == nil {
				return errorHandler(404, "Page not found")
			}
			currentNode = nextNode!
		default:
			return errorHandler(404, "Page not found (not a directory)")
		}
	}
	
	return getEndNodeValue(node: currentNode, request: request, connection: connection)
}
