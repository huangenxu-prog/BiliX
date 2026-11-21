import SwiftUI
import WebKit

struct BiliWebPlayer: UIViewRepresentable {
    let bvid: String
    let played: () -> Void

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var id: String?
        var reported = false
        let played: () -> Void
        init(_ played: @escaping () -> Void) { self.played = played }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard !reported else { return }
            reported = true
            played()
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(played) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences.isElementFullscreenEnabled = true
        config.userContentController.add(context.coordinator, name: "played")
        let script = """
        function configure(video) {
            video.controls = true;
            if (video.dataset.bilix) return;
            video.dataset.bilix = '1';
            video.addEventListener('playing', () => window.webkit.messageHandlers.played.postMessage(true));
            const controls = document.createElement('div');
            controls.style.cssText = 'position:absolute;top:8px;right:8px;display:flex;gap:6px;z-index:2147483647';
            const speed = document.createElement('select');
            speed.setAttribute('aria-label', '播放速度');
            [0.75, 1, 1.25, 1.5, 2].forEach(rate => speed.add(new Option(rate + '×', rate, false, rate === 1)));
            speed.onchange = () => { video.playbackRate = Number(speed.value); };
            const full = document.createElement('button');
            full.textContent = '全屏';
            full.onclick = () => {
                if (video.webkitEnterFullscreen) video.webkitEnterFullscreen();
                else if (video.requestFullscreen) video.requestFullscreen();
            };
            controls.append(speed, full);
            video.parentElement.appendChild(controls);
        }
        function refresh() { document.querySelectorAll('video').forEach(configure); }
        refresh();
        new MutationObserver(refresh).observe(document.documentElement, {childList:true, subtree:true});
        """
        config.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        return web
    }
    func updateUIView(_ web: WKWebView, context: Context) {
        guard context.coordinator.id != bvid else { return }
        context.coordinator.id = bvid
        context.coordinator.reported = false
        var url = URLComponents(string: "https://player.bilibili.com/player.html")!
        url.queryItems = ["bvid":bvid, "autoplay":"0", "danmaku":"0"].map { URLQueryItem(name: $0.key, value: $0.value) }
        web.load(URLRequest(url: url.url!))
    }
    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "played")
        web.pauseAllMediaPlayback()
        web.stopLoading()
    }
}
