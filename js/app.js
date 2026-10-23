// Shared helpers for every app screen (Fathima). Text, money format, nav, toast.
import { icon } from './icons.js';
export { icon };

const strings = await fetch('data/ml.json').then((r) => r.json()).catch(() => ({}));

// Malayalam text for a key. Falls back to English, then to the key itself.
export const ml = (key) => strings[key]?.ml ?? strings[key]?.en ?? key;
export const en = (key) => strings[key]?.en ?? key;

// Two-line label: Malayalam first, English smaller under it.
export const label = (key) => `<span class="ml">${ml(key)}</span><span class="en">${en(key)}</span>`;

// Escape text the user typed before putting it into HTML.
export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// Page header with a back button and a two-line title.
export function topbar(key) {
  return `<header class="topbar">
    <a class="back" href="index.html" aria-label="${en('back')}">${icon('back')}</a>
    <h1>${label(key)}</h1>
  </header>`;
}

const inr = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 });
export const rupees = (n) => `${n < 0 ? '−' : ''}₹${inr.format(Math.abs(Math.round(n)))}`;

// Installable app + offline support on every page that uses app.js.
if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});

const NAV = [
  { key: 'nav_home', href: 'index.html', icon: 'home' },
  { key: 'nav_daily', href: 'daily.html', icon: 'receipt' },
  { key: 'nav_profit', href: 'profit.html', icon: 'trend' },
  { key: 'nav_money', href: 'money.html', icon: 'wallet' },
  { key: 'nav_call', href: 'call.html', icon: 'phone' },
];

export function renderNav() {
  const here = location.pathname.split('/').pop() || 'index.html';
  const nav = document.createElement('nav');
  nav.className = 'bottom-nav';
  nav.setAttribute('aria-label', 'Main');
  nav.innerHTML = NAV.map((n) => `
    <a href="${n.href}" class="${n.href === here ? 'on' : ''}" ${n.href === here ? 'aria-current="page"' : ''}>
      ${icon(n.icon, 22)}
      <span class="ml">${ml(n.key)}</span>
    </a>`).join('');
  document.body.append(nav);
}

// Short message at the bottom. `key` is a ml.json key (shown in Malayalam · English) or plain text.
export function toast(keyOrText, iconName = 'check') {
  const text = ml(keyOrText) === keyOrText ? keyOrText : `${ml(keyOrText)} · ${en(keyOrText)}`;
  const el = document.createElement('div');
  el.className = 'toast';
  el.setAttribute('role', 'status');
  el.innerHTML = `${icon(iconName, 18)}<span>${esc(text)}</span>`;
  document.body.append(el);
  setTimeout(() => el.remove(), 3200);
}
