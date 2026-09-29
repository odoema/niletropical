(function () {
  try {
    var standalone = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
    if (standalone) return;
    if (sessionStorage.getItem('nileInstallDismissed') === '1') return;

    var deferredPrompt = null;
    var logo = 'favicon.png';

    function hide(el) {
      if (el && el.parentNode) el.parentNode.removeChild(el);
    }

    function banner() {
      if (document.getElementById('nile-install')) return;
      var wrap = document.createElement('div');
      wrap.id = 'nile-install';
      wrap.setAttribute('role', 'dialog');
      wrap.setAttribute('aria-label', 'Install Nile Tropical');
      wrap.style.cssText = 'position:fixed;left:10px;right:10px;bottom:10px;z-index:2147483647;display:flex;gap:12px;align-items:center;padding:12px 14px;border-radius:16px;background:#003d70;color:#fff;box-shadow:0 16px 40px rgba(0,0,0,.35);font-family:Arial,Helvetica,sans-serif;pointer-events:auto';
      wrap.innerHTML =
        '<img src="' + logo + '" alt="Nile Tropical" width="48" height="48" style="border-radius:12px;background:#fff;object-fit:contain;flex:0 0 48px;padding:4px">' +
        '<div style="min-width:0;flex:1">' +
        '<strong style="display:block;font-size:14px">Install Nile Tropical</strong>' +
        '<span style="display:block;font-size:12px;color:#dcecf5;margin-top:2px">Add the shop to your phone with the Nile Tropical logo</span>' +
        '</div>' +
        '<button type="button" id="nile-install-go" style="border:0;border-radius:10px;background:#fff;color:#005090;font-weight:800;padding:10px 12px;cursor:pointer">Install</button>' +
        '<button type="button" id="nile-install-x" aria-label="Not now" style="border:0;background:transparent;color:#fff;font-size:22px;line-height:1;cursor:pointer">\u00d7</button>';
      document.body.appendChild(wrap);
      document.getElementById('nile-install-x').onclick = function () {
        sessionStorage.setItem('nileInstallDismissed', '1');
        hide(wrap);
      };
      document.getElementById('nile-install-go').onclick = function () {
        if (deferredPrompt) {
          deferredPrompt.prompt();
          deferredPrompt.userChoice.then(function () {
            deferredPrompt = null;
            hide(wrap);
          });
          return;
        }
        wrap.querySelector('span').textContent =
          'Open the Chrome menu and tap Add to Home screen. Use the Nile Tropical logo.';
      };
    }

    window.addEventListener('beforeinstallprompt', function (e) {
      e.preventDefault();
      deferredPrompt = e;
      banner();
    });

    window.addEventListener('appinstalled', function () {
      sessionStorage.setItem('nileInstallDismissed', '1');
      hide(document.getElementById('nile-install'));
    });

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', banner);
    } else {
      banner();
    }
    window.addEventListener('flutter-first-frame', banner);
    setTimeout(banner, 1500);
  } catch (err) {
    console.warn('Nile Tropical install prompt', err);
  }
})();
