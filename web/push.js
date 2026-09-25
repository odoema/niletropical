// Nile Tropical free Web Push bridge.
// Standard Web Push + VAPID. No Firebase, no paid SMS provider.
(function () {
  function base64UrlToUint8Array(base64Url) {
    const padding = "=".repeat((4 - (base64Url.length % 4)) % 4);
    const base64 = (base64Url + padding).replace(/-/g, "+").replace(/_/g, "/");
    const raw = atob(base64);
    return Uint8Array.from([...raw].map((char) => char.charCodeAt(0)));
  }

  window.nilePushPermission = function () {
    if (!("Notification" in window)) return "unsupported";
    return Notification.permission;
  };

  window.nilePushSubscribe = async function (publicKey) {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      throw new Error("Web Push is not supported by this browser.");
    }

    if (!("Notification" in window)) {
      throw new Error("Browser notifications are not supported.");
    }

    if (Notification.permission !== "granted") {
      const permission = await Notification.requestPermission();
      if (permission !== "granted") {
        return null;
      }
    }

    // Keep this worker under its own scope so it does not interfere with
    // Flutter's generated service worker.
    const workerUrl = new URL("push_service_worker.js", document.baseURI);
    const scopeUrl = new URL("push/", document.baseURI);

    const registration = await navigator.serviceWorker.register(workerUrl, {
      scope: scopeUrl.pathname,
      updateViaCache: "none",
    });

    await navigator.serviceWorker.ready;

    let subscription = await registration.pushManager.getSubscription();

    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: base64UrlToUint8Array(publicKey),
      });
    }

    return JSON.stringify(subscription.toJSON());
  };
})();
