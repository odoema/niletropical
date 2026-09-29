(function () {
  var ua = navigator.userAgent || '';
  var isAndroid = /Android/i.test(ua);
  var standalone = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  if (!isAndroid || standalone) return;
  if (localStorage.getItem('nileInstallDismissed') === '1') return;

  var deferredPrompt = null;
  var logo = 'favicon.png';

  function hide(el) {
    if (el && el.parentNode) el.parentNode.removeChild(el);
  }

  function banner(canInstall) {
    if (document.getElementById('nile-install')) return;
    var wrap = document.createElement('div');
    wrap.id = 'nile-install';
    wrap.setAttribute('role', 'dialog');
    wrap.setAttribute('aria-label', 'Install Nile Tropical');
    wrap.style.cssText = 'position:fixed;left:12px;right:12px;bottom:12px;z-index:10000;display:flex;gap:12px;align-items:center;padding:12px 14px;border-radius:16px;background:#003d70;color:#fff;box-shadow:0 16px 40px rgba(0,0,0,.28);font-family:Arial,Helvetica,sans-serif';
    wrap.innerHTML =
      '<img src="' + logo + '" alt="Nile Tropical" width="48" height="48" style="border-radius:12px;background:#fff;object-fit:contain;flex:0 0 48px;padding:4px">' +
      '<div style="min-width:0;flex:1">' +
      '<strong style="display:block;font-size:14px">Install Nile Tropical</strong>' +
      '<span style="display:block;font-size:12px;color:#dcecf5;margin-top:2px">Add it to your phone like other apps</span>' +
      '</div>' +
      '<button type="button" id="nile-install-go" style="border:0;border-radius:10px;background:#fff;color:#005090;font-weight:800;padding:10px 12px;cursor:pointer">Install</button>' +
      '<button type="button" id="nile-install-x" aria-label="Not now" style="border:0;background:transparent;color:#fff;font-size:20px;line-height:1;cursor:pointer">×</button>';
    document.body.appendChild(wrap);
    document.getElementById('nile-install-x').onclick = function () {
      localStorage.setItem('nileInstallDismissed', '1');
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
        'Chrome menu → Add to Home screen. The Nile Tropical logo will appear with your other apps.';
    };
    if (!canInstall) {
      wrap.querySelector('span').textContent =
        'Tap Install, then choose Add to Home screen.';
    }
  }

  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    deferredPrompt = e;
    banner(true);
  });

  window.addEventListener('appinstalled', function () {
    localStorage.setItem('nileInstallDismissed', '1');
    hide(document.getElementById('nile-install'));
  });

  setTimeout(function () {
    banner(!!deferredPrompt);
  }, 2200);
})();
