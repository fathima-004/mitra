// Shared helpers for every app screen (Fathima). Text, money format, nav, toast.

const strings = await fetch('data/ml.json').then((r) => r.json()).catch(() => ({}));

// Malayalam text for a key. Falls back to English, then to the key itself.
export const ml = (key) => strings[key]?.ml ?? strings[key]?.en ?? key;
export const en = (key) => strings[key]?.en ?? key;

// Two-line label: Malayalam big, English small under it.
export const label = (key) => `<span class="ml">${ml(key)}</span><span class="en">${en(key)}</span>`;

// Escape text the user typed before putting it into HTML.
export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// Page header with a back button and a two-line title.
export function topbar(key) {
  return `<header class="topbar">
    <a class="back" href="index.html" aria-label="${en('back')}">←</a>
    <h1>${label(key)}</h1>
  </header>`;
}

const inr = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 });
export const rupees = (n) => `${n < 0 ? '−' : ''}₹${inr.format(Math.abs(Math.round(n)))}`;

const NAV = [
  { key: 'nav_home', href: 'index.html', icon: '🏠' },
  { key: 'nav_daily', href: 'daily.html', icon: '🧾' },
  { key: 'nav_profit', href: 'profit.html', icon: '📈' },
  { key: 'nav_money', href: 'money.html', icon: '🪙' },
  { key: 'nav_call', href: 'call.html', icon: '📞' },
];

// Installable app + offline support on every page that uses app.js.
if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});

export function renderNav() {
  const here = location.pathname.split('/').pop() || 'index.html';
  const nav = document.createElement('nav');
  nav.className = 'bottom-nav';
  nav.innerHTML = NAV.map((n) => `
    <a href="${n.href}" class="${n.href === here ? 'on' : ''}" ${n.href === here ? 'aria-current="page"' : ''}>
      <span class="icon" aria-hidden="true">${n.icon}</span>
      <span class="ml">${ml(n.key)}</span>
    </a>`).join('');
  document.body.append(nav);
}

export function toast(text) {
  const el = document.createElement('div');
  el.className = 'toast';
  el.setAttribute('role', 'status');
  el.textContent = text;
  document.body.append(el);
  setTimeout(() => el.remove(), 3200);
}
