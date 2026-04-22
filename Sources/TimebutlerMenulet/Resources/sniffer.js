(function () {
  if (window.__tb_sniffer_installed__) return;
  window.__tb_sniffer_installed__ = true;

  function forward(payload) {
    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tb) {
        window.webkit.messageHandlers.tb.postMessage(payload);
      }
    } catch (e) { /* noop */ }
  }

  function absolutize(u) {
    try { return new URL(u, location.href).toString(); }
    catch (e) { return String(u); }
  }

  function bodyToString(b) {
    if (b == null) return null;
    if (typeof b === 'string') return b;
    if (typeof URLSearchParams !== 'undefined' && b instanceof URLSearchParams) return b.toString();
    if (typeof FormData !== 'undefined' && b instanceof FormData) {
      const pairs = [];
      for (const [k, v] of b.entries()) {
        pairs.push(encodeURIComponent(k) + '=' + encodeURIComponent(typeof v === 'string' ? v : ''));
      }
      return pairs.join('&');
    }
    try { return String(b); } catch (e) { return null; }
  }

  // fetch
  const origFetch = window.fetch;
  if (origFetch) {
    window.fetch = function (input, init) {
      try {
        const url = typeof input === 'string' ? input : (input && input.url) || '';
        const method = ((init && init.method)
          || (typeof input !== 'string' && input && input.method)
          || 'GET').toUpperCase();
        const body = init && init.body ? bodyToString(init.body) : null;
        forward({ kind: 'fetch', url: absolutize(url), method: method, body: body, at: Date.now() });
      } catch (e) { /* noop */ }
      return origFetch.apply(this, arguments);
    };
  }

  // XMLHttpRequest
  const origOpen = XMLHttpRequest.prototype.open;
  const origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (m, u) {
    this.__tb_method = (m || 'GET').toUpperCase();
    this.__tb_url = u;
    return origOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function (body) {
    try {
      forward({
        kind: 'xhr',
        url: absolutize(this.__tb_url || ''),
        method: this.__tb_method || 'GET',
        body: bodyToString(body),
        at: Date.now()
      });
    } catch (e) { /* noop */ }
    return origSend.apply(this, arguments);
  };

  // Form submissions (covers classic server-rendered forms)
  document.addEventListener('submit', function (e) {
    try {
      const f = e.target;
      if (!(f instanceof HTMLFormElement)) return;
      const fd = new FormData(f);
      const pairs = [];
      for (const [k, v] of fd.entries()) {
        pairs.push(encodeURIComponent(k) + '=' + encodeURIComponent(typeof v === 'string' ? v : ''));
      }
      forward({
        kind: 'form',
        url: absolutize(f.action || location.href),
        method: (f.method || 'POST').toUpperCase(),
        body: pairs.join('&'),
        at: Date.now()
      });
    } catch (err) { /* noop */ }
  }, true);
})();
