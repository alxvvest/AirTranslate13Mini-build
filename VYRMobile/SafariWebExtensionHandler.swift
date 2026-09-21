import Foundation
import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        guard
            let item = context.inputItems.first as? NSExtensionItem,
            let message = item.userInfo?[SFExtensionMessageKey] as? [String: Any],
            (message["type"] as? String) == "VYR_MOBILE_REASON",
            let snapshot = message["snapshot"] as? [String: Any],
            let token = message["token"] as? String,
            token.count >= 24
        else {
            finish(context, ["ok": false, "error": "invalid_or_unpaired"])
            return
        }

        guard let url = URL(string: "https://ivyre.vyres.net/api/revenue/form/reason") else {
            finish(context, ["ok": false, "error": "endpoint_invalid"])
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 130
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-VYR-Mobile-Token")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "snapshot": snapshot,
                "context": ["source": "vyr-mobile-safari"]
            ])
        } catch {
            finish(context, ["ok": false, "error": "snapshot_encode_failed"])
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.finish(context, [
                    "ok": false,
                    "error": "network_error",
                    "detail": error.localizedDescription
                ])
                return
            }
            guard
                let http = response as? HTTPURLResponse,
                let data,
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                self.finish(context, ["ok": false, "error": "invalid_response"])
                return
            }
            self.finish(context, [
                "ok": (200..<300).contains(http.statusCode),
                "status": http.statusCode,
                "plan": object
            ])
        }.resume()
    }

    private func finish(_ context: NSExtensionContext, _ payload: [String: Any]) {
        let item = NSExtensionItem()
        item.userInfo = [SFExtensionMessageKey: payload]
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
}
