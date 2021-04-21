import Foundation
import HyperSwift
import Network

let errorMessages: Dictionary<String, String> = [
	"404": "Page not found",
	"404.long": "The page you were looking for does not exist.",
	"404.tooFar": "Page not found (not a directory)",
	"404.tooFar.long": "One of the path nodes in the provided URL is not a directory.",
	"400.url": "Bad request (invalid URL)",
	"400.url.long": "The provided URL was not able to be processed by the server."
]

enum SiteNode {
	case file(name: String, type: String)
	case literal(text: String, type: String)
	indirect case subDir(default: SiteNode, error: (Int, String) -> Response, subNodes: Dictionary<String, SiteNode>)
	case redirect(toURL: String)
	case special(resolver: (Request?, NWConnection) -> Response)
}

func getEndNodeValue(node: SiteNode, request: Request, connection: NWConnection) -> Response {
	switch node {
	case .file(name: let name, type: let type):
		let fileContent = try? Data(contentsOf: URL(fileURLWithPath: name))
		return Response(code: 200, reason: "Success", headers: ["Content-Type": type], body: fileContent)
	case .redirect(toURL: let redirectURL):
		return Response(code: 300, reason: "Moved permanently", headers: ["Content-Type": "text/html"], body: "<script>window.location='\(redirectURL)';</script><noscript><a href='\(redirectURL)'>Click here to redirect</a></noscript>".data(using: .utf8))
	case .special(resolver: let resolver):
		return resolver(request, connection)
	case .subDir(default: let deflt, error: _, subNodes: _):
		return getEndNodeValue(node: deflt, request: request, connection: connection)
	case .literal(text: let text, type: let cType):
		return Response(code: 200, reason: "Success", headers: ["Content-Type": cType], body: text.data(using: .utf8))
	}
}

func evaluateRequest(request: Request, baseNode: SiteNode, connection: NWConnection) -> Response {
	if request.parsedURL == nil {
		switch baseNode {
		case .subDir(default: _, error: let errorHandler, subNodes: _):
			return errorHandler(400, errorMessages["400.url"]!)
		default:
			return Response(code: 400, reason: errorMessages["400.url"]!, headers: ["Content-Type": "text/plain"], body: "400: \(errorMessages["400.url"]!)\n\n\(errorMessages["400.url.long"]!)".data(using: .utf8))
		}
	}
	
	var currentNode = baseNode
	for nodeName in request.parsedURL!.path {
		switch currentNode {
		case .subDir(default: _, error: let errorHandler, subNodes: let subnodes):
			let nextNode = subnodes[nodeName]
			if nextNode == nil {
				return errorHandler(404, "Page not found")
			}
			currentNode = nextNode!
		default:
			return Response(code: 404, reason: "Page not found (not a directory)", headers: ["Content-Type": "text/plain"], body: "404: \(errorMessages["404.tooFar"]!)\n\n\(errorMessages["404.tooFar.long"]!)".data(using: .utf8))
		}
	}
	
	return getEndNodeValue(node: currentNode, request: request, connection: connection)
}
