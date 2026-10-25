// Disposable macOS WKWebView storage fixture. Never opens the installed app store.
import AppKit
import WebKit

let args = CommandLine.arguments
guard args.count == 5, ["write", "read"].contains(args[1]),
      let identifier = UUID(uuidString: args[2]),
      let url = URL(string: args[3]), url.host == "127.0.0.1",
      url.scheme == "http" else {
  fputs("usage: webkit_fixture write|read NEW_FIXTURE_UUID http://127.0.0.1:PORT/fixture.html OUTPUT.json\n", stderr)
  exit(2)
}
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

@available(macOS 14.0, *)
final class Fixture: NSObject, WKNavigationDelegate {
  let view: WKWebView
  let url: URL
  init(identifier: UUID, url: URL) {
    self.url = url
    let config = WKWebViewConfiguration()
    config.websiteDataStore = WKWebsiteDataStore(forIdentifier: identifier)
    view = WKWebView(frame: NSRect(x: 0, y: 0, width: 500, height: 300), configuration: config)
    super.init()
    view.navigationDelegate = self
  }
  func start() { view.load(URLRequest(url: url)) }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let script = args[1] == "write"
      ? "fixtureSeed(); JSON.stringify(Object.fromEntries(Object.keys(localStorage).sort().map(k => [k, localStorage.getItem(k)])))"
      : "JSON.stringify(Object.fromEntries(Object.keys(localStorage).sort().map(k => [k, localStorage.getItem(k)])))"
    webView.evaluateJavaScript(script) { value, error in
      guard error == nil, let text = value as? String else {
        fputs("fixture JavaScript failed\n", stderr); exit(3)
      }
      do { try text.write(toFile: args[4], atomically: true, encoding: .utf8) }
      catch { fputs("fixture output write failed\n", stderr); exit(4) }
      // WebKit persists asynchronously; keep its normal run loop alive before process exit.
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) { app.terminate(nil) }
    }
  }
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    fputs("fixture navigation failed\n", stderr); exit(5)
  }
}

if #available(macOS 14.0, *) {
  let fixture = Fixture(identifier: identifier, url: url)
  fixture.start()
  DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
    fputs("fixture timeout\n", stderr); exit(6)
  }
  app.run()
  withExtendedLifetime(fixture) {}
} else {
  fputs("macOS 14+ required for isolated named WKWebsiteDataStore\n", stderr); exit(7)
}
