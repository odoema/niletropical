{{flutter_js}}
{{flutter_build_config}}

const loading = document.createElement('div');
loading.id = 'flutter-loading';
loading.style.cssText = 'position:fixed;inset:0;display:flex;align-items:center;justify-content:center;font-family:Arial,sans-serif;color:#005090;background:#fff;z-index:9999';
loading.textContent = 'Loading Nile Tropical…';
document.body.appendChild(loading);

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      loading.textContent = 'Starting Nile Tropical…';
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      loading.remove();
    } catch (error) {
      loading.style.alignItems = 'flex-start';
      loading.style.padding = '32px';
      loading.style.boxSizing = 'border-box';
      loading.innerHTML = '<div style="max-width:760px"><h2 style="margin:0 0 12px">Nile Tropical could not start</h2><p style="line-height:1.5">The web app loaded, but Flutter failed during startup. Refresh the page once. If the problem continues, please report this message.</p><pre style="white-space:pre-wrap;overflow:auto;background:#f5f5f5;padding:12px;border-radius:8px;font-size:12px"></pre></div>';
      const details = loading.querySelector('pre');
      if (details) details.textContent = String(error);
      console.error('[Nile Tropical] Flutter startup failed:', error);
    }
  }
});
