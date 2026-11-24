// Рисует значки и картинку заставки из SVG в PNG. Запуск: node tools/icons.mjs
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
const out = path.join(__dirname, '..', 'assets', 'icon');
const gem = (x, y, s, c, light) => `
  <g transform="translate(${x},${y})">
    <rect x="${-s*0.12}" y="${-s*0.12}" width="${s*1.24}" height="${s*1.24}" rx="${s*0.3}" fill="${c}" opacity="0.22"/>
    <rect width="${s}" height="${s}" rx="${s*0.2}" fill="${c}" filter="brightness(0.6)"/>
    <rect width="${s}" height="${s*0.9}" rx="${s*0.2}" fill="url(#g${c.slice(1)})"/>
    <path d="M${s*0.14} ${s*0.14} h${s*0.42} L${s*0.14} ${s*0.56}Z" fill="#fff" opacity="0.32"/>
    <path d="M${s*0.72} ${s*0.12} l${s*0.07} ${s*0.07} l${-s*0.07} ${s*0.07} l${-s*0.07} ${-s*0.07}Z" fill="#fff" opacity="0.85"/>
  </g>`;
const grads = ['#FFB547','#FF4D6D','#B46CFF','#3FD0FF'].map(c => `
  <linearGradient id="g${c.slice(1)}" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${c}" stop-opacity="1"/><stop offset="1" stop-color="${c}"/>
  </linearGradient>`).join('');
// Ступенька самоцветов: каскад сверху-слева вниз-вправо. Координаты в системе 108x108 (адаптивный значок).
const fg = `
  ${gem(26, 24, 17, '#FFB547')}
  ${gem(39, 38, 19, '#FF4D6D')}
  ${gem(52, 52, 21, '#B46CFF')}
  ${gem(60, 66, 26, '#3FD0FF')}
  <path d="M86 70 l2 5 l5 2 l-5 2 l-2 5 l-2 -5 l-5 -2 l5 -2Z" fill="#fff"/>`;
// Рисунок занимает примерно 24..93 x 22..92: центрируем его в 54,54
const center = (body, k) => `<g transform="translate(54 54) scale(${k}) translate(-58.5 -57)">${body}</g>`;
const bg = `
  <radialGradient id="bg" cx="0.5" cy="0.45" r="0.7">
    <stop offset="0" stop-color="#3A2470"/><stop offset="1" stop-color="#120B24"/>
  </radialGradient>`;
const svg = (w, body, defs='') => `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${w}" viewBox="0 0 108 108"><defs>${grads}${defs}</defs>${body}</svg>`;
const files = {
  'icon_fg_432.png': [432, svg(432, center(fg, 0.8))],
  'icon_bg_432.png': [432, svg(432, `<rect width="108" height="108" fill="url(#bg)"/>`, bg)],
  'icon_192.png': [192, svg(192, `<rect x="6" y="6" width="96" height="96" rx="24" fill="url(#bg)"/>${center(fg, 1.1)}`, bg)],
  'icon_512.png': [512, svg(512, `<rect width="108" height="108" fill="url(#bg)"/>${center(fg, 1.25)}`, bg)],
};
const owl = `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="700" viewBox="0 0 600 700">
  <rect width="600" height="700" fill="#120B24"/>
  <circle cx="300" cy="260" r="150" fill="#2A1A4F"/>
  <path d="M180 190 L260 182 L195 120Z M420 190 L340 182 L405 120Z" fill="#A79BC9"/>
  <circle cx="242" cy="250" r="44" fill="none" stroke="#F4EEFF" stroke-width="8"/>
  <circle cx="358" cy="250" r="44" fill="none" stroke="#F4EEFF" stroke-width="8"/>
  <circle cx="242" cy="250" r="26" fill="#FFB547" opacity="0.25"/><circle cx="358" cy="250" r="26" fill="#FFB547" opacity="0.25"/>
  <circle cx="242" cy="250" r="16" fill="#FFB547"/><circle cx="358" cy="250" r="16" fill="#FFB547"/>
  <path d="M288 300 L312 300 L300 322Z" fill="#FFB547"/>
  <text x="300" y="540" text-anchor="middle" font-family="DejaVu Sans, sans-serif" font-weight="bold" font-size="64" fill="#F4EEFF">OWLIGHT</text>
  <text x="300" y="590" text-anchor="middle" font-family="DejaVu Sans, sans-serif" font-size="26" letter-spacing="10" fill="#A79BC9">GAMES</text>
</svg>`;
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  for (const [name, [w, s]] of Object.entries(files)) {
    await p.setViewportSize({ width: w, height: w });
    await p.setContent(`<html><body style="margin:0;background:transparent">${s}</body></html>`);
    await p.screenshot({ path: path.join(out, name), omitBackground: true, clip: { x: 0, y: 0, width: w, height: w } });
  }
  await p.setViewportSize({ width: 600, height: 700 });
  await p.setContent(`<html><body style="margin:0">${owl}</body></html>`);
  await p.screenshot({ path: path.join(out, '..', 'splash.png'), clip: { x: 0, y: 0, width: 600, height: 700 } });
  await b.close(); console.log('ok');
})();
