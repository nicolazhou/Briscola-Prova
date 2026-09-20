#!/usr/bin/env python3
from __future__ import annotations

import html
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "web"
INDEX = BUILD / "index.html"

version = os.environ.get("BRISCOLA_VERSION", "0.8.3-rc8")
commit = os.environ.get("GITHUB_SHA", "local")
repo = os.environ.get("GITHUB_REPOSITORY", "")
support_url = os.environ.get("SUPPORT_URL", "").strip()
error_endpoint = os.environ.get("ERROR_REPORT_ENDPOINT", "").strip()
playtest_endpoint = os.environ.get("PLAYTEST_ENDPOINT", "").strip()

if not support_url and repo:
    support_url = f"https://github.com/{repo}/issues/new"

runtime = f"""(() => {{
  'use strict';
  const CONFIG = {json.dumps({
    'version': version,
    'commit': commit,
    'supportUrl': support_url,
    'errorEndpoint': error_endpoint,
    'playtestEndpoint': playtest_endpoint,
  }, ensure_ascii=False)};
  const STORAGE_KEY = 'briscola_runtime_errors_v1';
  const MAX_ERRORS = 10;
  window.__briscolaAppReady = false;
  window.__briscolaQaStatus = 'booting';
  window.BriscolaRuntimeConfig = CONFIG;

  function compact(value, max = 1800) {{
    let text = '';
    try {{
      text = typeof value === 'string' ? value : JSON.stringify(value);
    }} catch (_) {{
      text = String(value);
    }}
    return text.slice(0, max);
  }}

  function readErrors() {{
    try {{
      const parsed = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
      return Array.isArray(parsed) ? parsed : [];
    }} catch (_) {{
      return [];
    }}
  }}

  function writeErrors(items) {{
    try {{ localStorage.setItem(STORAGE_KEY, JSON.stringify(items.slice(-MAX_ERRORS))); }} catch (_) {{}}
  }}

  function report(type, message, stack = '') {{
    const event = {{
      type: compact(type, 80),
      message: compact(message),
      stack: compact(stack, 3500),
      path: location.pathname,
      userAgent: navigator.userAgent,
      version: CONFIG.version,
      commit: CONFIG.commit,
      timestamp: new Date().toISOString(),
    }};
    const items = readErrors();
    items.push(event);
    writeErrors(items);

    if (CONFIG.errorEndpoint) {{
      try {{
        fetch(CONFIG.errorEndpoint, {{
          method: 'POST',
          headers: {{'content-type': 'application/json'}},
          body: JSON.stringify(event),
          keepalive: true,
          credentials: 'omit',
          referrerPolicy: 'no-referrer',
        }}).catch(() => {{}});
      }} catch (_) {{}}
    }}
  }}

  const originalConsoleError = console.error.bind(console);
  console.error = (...args) => {{
    try {{ report('console.error', args.map(x => compact(x, 700)).join(' | ')); }} catch (_) {{}}
    originalConsoleError(...args);
  }};

  addEventListener('error', (event) => {{
    report('window.error', event.message || 'Unknown browser error', event.error && event.error.stack || '');
  }});
  addEventListener('unhandledrejection', (event) => {{
    const reason = event.reason;
    report('unhandledrejection', compact(reason), reason && reason.stack || '');
  }});

  let deferredInstallPrompt = null;
  let serviceWorkerRegistration = null;
  let updateAvailable = false;
  addEventListener('beforeinstallprompt', (event) => {{
    event.preventDefault();
    deferredInstallPrompt = event;
    window.dispatchEvent(new CustomEvent('briscola-install-available'));
  }});
  addEventListener('appinstalled', () => {{ deferredInstallPrompt = null; }});

  function isStandalone() {{
    return matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  }}

  window.BriscolaPWA = {{
    async install() {{
      if (isStandalone()) {{
        alert('Briscola Napoletana è già installata.');
        return true;
      }}
      if (deferredInstallPrompt) {{
        deferredInstallPrompt.prompt();
        try {{ await deferredInstallPrompt.userChoice; }} catch (_) {{}}
        deferredInstallPrompt = null;
        return true;
      }}
      const ua = navigator.userAgent || '';
      const ios = /iPhone|iPad|iPod/.test(ua);
      if (ios) {{
        alert('Su iPhone/iPad: apri Condividi in Safari e scegli “Aggiungi alla schermata Home”.');
      }} else {{
        alert('Apri il menu del browser e scegli “Installa app” o “Aggiungi alla schermata Home”.');
      }}
      return false;
    }},
    state() {{
      return {{ installed: isStandalone(), installPromptAvailable: !!deferredInstallPrompt, updateAvailable }};
    }},
    async checkForUpdate() {{
      if (!serviceWorkerRegistration) return false;
      try {{ await serviceWorkerRegistration.update(); }} catch (_) {{ return false; }}
      return updateAvailable || !!serviceWorkerRegistration.waiting;
    }},
    applyUpdate() {{
      if (!serviceWorkerRegistration || !serviceWorkerRegistration.waiting) return false;
      let reloading = false;
      navigator.serviceWorker.addEventListener('controllerchange', () => {{
        if (reloading) return;
        reloading = true;
        location.reload();
      }});
      serviceWorkerRegistration.waiting.postMessage({{type: 'SKIP_WAITING'}});
      return true;
    }},
  }};

  if ('serviceWorker' in navigator) {{
    addEventListener('load', () => {{
      navigator.serviceWorker.register(`service-worker.js?build=${{encodeURIComponent(CONFIG.commit)}}`, {{ scope: './' }})
        .then((registration) => {{
          serviceWorkerRegistration = registration;
          if (registration.waiting && navigator.serviceWorker.controller) {{
            updateAvailable = true;
            window.dispatchEvent(new CustomEvent('briscola-update-available'));
          }}
          registration.addEventListener('updatefound', () => {{
            const installing = registration.installing;
            if (!installing) return;
            installing.addEventListener('statechange', () => {{
              if (installing.state === 'installed' && navigator.serviceWorker.controller) {{
                updateAvailable = true;
                window.dispatchEvent(new CustomEvent('briscola-update-available'));
              }}
            }});
          }});
        }})
        .catch((error) => report('service_worker', error && error.message || String(error), error && error.stack || ''));
    }});
  }}

  window.BriscolaSupport = {{
    openFeedback(kind = 'general') {{
      if (!CONFIG.supportUrl) return false;
      try {{
        const target = new URL(CONFIG.supportUrl, location.href);
        const recent = readErrors().slice(-3);
        const title = kind === 'playtest' ? '[Playtest] Feedback Briscola' : '[Feedback] Briscola';
        const body = [
          '### Tipo', kind,
          '',
          '### Descrizione',
          'Scrivi qui cosa hai notato:',
          '',
          '### Diagnostica',
          `Versione: ${{CONFIG.version}}`,
          `Commit: ${{CONFIG.commit.slice(0, 12)}}`,
          `Browser: ${{navigator.userAgent}}`,
          `Viewport: ${{innerWidth}}x${{innerHeight}}`,
          recent.length ? `Errori recenti (automatici):\\n\\`\\`\\`json\\n${{JSON.stringify(recent, null, 2)}}\\n\\`\\`\\`` : 'Errori recenti: nessuno rilevato',
        ].join('\\n');
        target.searchParams.set('title', title);
        target.searchParams.set('body', body);
        window.open(target.toString(), '_blank', 'noopener,noreferrer');
        return true;
      }} catch (_) {{
        return false;
      }}
    }},
    recordPlaytest(difficulty, rating, humanScore, cpuScore, mode = 'classic_2p') {{
      const event = {{
        type: 'ai_playtest',
        difficulty: compact(difficulty, 30),
        rating: compact(rating, 30),
        mode: compact(mode, 30),
        humanScore: Number(humanScore) || 0,
        cpuScore: Number(cpuScore) || 0,
        version: CONFIG.version,
        commit: CONFIG.commit,
        userAgent: navigator.userAgent,
        timestamp: new Date().toISOString(),
      }};
      try {{
        const key = 'briscola_playtest_feedback_v1';
        const current = JSON.parse(localStorage.getItem(key) || '[]');
        const items = Array.isArray(current) ? current : [];
        items.push(event);
        localStorage.setItem(key, JSON.stringify(items.slice(-50)));
      }} catch (_) {{}}
      if (CONFIG.playtestEndpoint) {{
        try {{
          fetch(CONFIG.playtestEndpoint, {{
            method: 'POST',
            headers: {{'content-type': 'application/json'}},
            body: JSON.stringify(event),
            keepalive: true,
            credentials: 'omit',
            referrerPolicy: 'no-referrer',
          }}).catch(() => {{}});
        }} catch (_) {{}}
      }}
      return true;
    }},
    getDiagnostics() {{ return readErrors(); }},
  }};

  setTimeout(() => {{
    if (!window.__briscolaAppReady) report('boot_timeout', 'Godot did not signal ready within 20 seconds');
  }}, 20000);
}})();
"""
(BUILD / "runtime.js").write_text(runtime, encoding="utf-8")

# PWA assets are versioned by build/commit so an update creates a new cache
# namespace. Navigation stays network-first to avoid stale production HTML.
pwa_src = ROOT / "assets" / "pwa"
for name in ("icon-192.png", "icon-512.png", "apple-touch-icon.png"):
    src = pwa_src / name
    if src.exists():
        (BUILD / name).write_bytes(src.read_bytes())

manifest = {
    "id": "./",
    "name": "Briscola Napoletana",
    "short_name": "Briscola",
    "description": "Briscola Napoletana, classica 1 contro 1 e modalità a squadre.",
    "start_url": "./",
    "scope": "./",
    "display": "standalone",
    "background_color": "#0d352b",
    "theme_color": "#0d352b",
    "orientation": "any",
    "categories": ["games", "entertainment"],
    "icons": [
        {"src": "icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any"},
        {"src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any"},
    ],
}
(BUILD / "manifest.webmanifest").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

offline_html = """<!doctype html><html lang="it"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#0d352b"><title>Briscola Napoletana · Offline</title><style>body{margin:0;background:#0d352b;color:#f5efe1;font-family:system-ui;display:grid;place-items:center;min-height:100vh;text-align:center}main{padding:2rem;max-width:32rem}button{padding:.8rem 1.2rem;border:0;border-radius:.7rem;background:#d6b45b;color:#102a23;font-weight:700}</style><main><h1>Briscola Napoletana</h1><p>Questa versione non è ancora disponibile offline su questo dispositivo. Collegati una volta a Internet e riapri il gioco.</p><button onclick="location.reload()">Riprova</button></main></html>"""
(BUILD / "offline.html").write_text(offline_html, encoding="utf-8")

cache_tag = f"{version}-{commit[:12]}"
precache = [
    "./", "index.html", "index.js", "index.wasm", "index.pck", "runtime.js",
    "manifest.webmanifest", "offline.html", "brand-icon.svg", "icon-192.png",
    "icon-512.png", "apple-touch-icon.png", "version.txt", "commit.txt",
]
service_worker = f"""'use strict';
const CACHE_NAME = {json.dumps('briscola-' + cache_tag)};
const CACHE_PREFIX = 'briscola-';
const PRECACHE = {json.dumps(precache)};
const scopeUrl = (path) => new URL(path, self.registration.scope).href;

self.addEventListener('install', (event) => {{
  event.waitUntil((async () => {{
    const cache = await caches.open(CACHE_NAME);
    for (const asset of PRECACHE) {{
      try {{
        const request = new Request(scopeUrl(asset), {{ cache: 'reload' }});
        const response = await fetch(request);
        if (response.ok) await cache.put(request, response.clone());
      }} catch (_) {{}}
    }}
  }})());
}});

self.addEventListener('activate', (event) => {{
  event.waitUntil((async () => {{
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k.startsWith(CACHE_PREFIX) && k !== CACHE_NAME).map(k => caches.delete(k)));
    await self.clients.claim();
  }})());
}});

self.addEventListener('message', (event) => {{
  if (event.data && event.data.type === 'SKIP_WAITING') self.skipWaiting();
}});

self.addEventListener('fetch', (event) => {{
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {{
    event.respondWith((async () => {{
      try {{
        const response = await fetch(request);
        if (response.ok) {{
          const cache = await caches.open(CACHE_NAME);
          cache.put(scopeUrl('index.html'), response.clone());
        }}
        return response;
      }} catch (_) {{
        return (await caches.match(scopeUrl('index.html'))) || (await caches.match(scopeUrl('offline.html')));
      }}
    }})());
    return;
  }}

  event.respondWith((async () => {{
    const cached = await caches.match(request);
    if (cached) return cached;
    try {{
      const response = await fetch(request);
      if (response.ok) {{
        const cache = await caches.open(CACHE_NAME);
        cache.put(request, response.clone());
      }}
      return response;
    }} catch (_) {{
      return Response.error();
    }}
  }})());
}});
"""
(BUILD / "service-worker.js").write_text(service_worker, encoding="utf-8")

if not INDEX.exists():
    raise SystemExit(f"Missing exported HTML: {INDEX}")

source = INDEX.read_text(encoding="utf-8")
apple_touch = '<link rel="apple-touch-icon" href="apple-touch-icon.png">\n' if (BUILD / "apple-touch-icon.png").exists() else ""
head_bits = f"""
<meta name="description" content="Briscola Napoletana: una partita classica contro Tony, direttamente nel browser.">
<meta name="theme-color" content="#0d352b">
<meta name="color-scheme" content="dark">
<meta name="application-name" content="Briscola Napoletana">
<meta property="og:title" content="Briscola Napoletana">
<meta property="og:description" content="Gioca a Briscola Napoletana contro Tony.">
<meta property="og:type" content="website">
<link rel="icon" type="image/svg+xml" href="brand-icon.svg">
<link rel="manifest" href="manifest.webmanifest">
{apple_touch}<script src="runtime.js"></script>
""".strip()
if "runtime.js" not in source:
    source = source.replace("</head>", head_bits + "\n</head>")
INDEX.write_text(source, encoding="utf-8")

# Brand assets for browsers. The PNG is created by CI before this script when possible;
# SVG always exists as a fallback.
icon_src = ROOT / "icon.svg"
if icon_src.exists():
    (BUILD / "brand-icon.svg").write_bytes(icon_src.read_bytes())

(BUILD / "monitoring-config.txt").write_text(
    "Error monitoring: " + ("remote endpoint configured\n" if error_endpoint else "local diagnostics only; configure ERROR_REPORT_ENDPOINT repository variable for remote collection\n")
    + "Support: " + (support_url or "not configured") + "\n"
    + "Playtest endpoint: " + ("configured" if playtest_endpoint else "local only") + "\n",
    encoding="utf-8",
)

print(f"Post-processed {INDEX}")
print(f"Support URL: {support_url or '(not configured)'}")
print(f"Remote error endpoint: {'configured' if error_endpoint else 'disabled'}")
