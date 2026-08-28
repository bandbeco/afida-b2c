// Generates public/game/og.png (1200x630 social card for The Afida Stack).
// Run: npm i --no-save @napi-rs/canvas && node script/game_og_image.js
const { createCanvas, loadImage, GlobalFonts } = require('@napi-rs/canvas');
const fs = require('fs');

const path = require('path');
const FONTS = path.join(__dirname, '../app/frontend/fonts/fredoka/static/');
GlobalFonts.registerFromPath(path.join(FONTS, 'Fredoka-Medium.ttf'), 'Fredoka Medium');
GlobalFonts.registerFromPath(path.join(FONTS, 'Fredoka-Regular.ttf'), 'Fredoka');

const W = 1200, H = 630;
const INK = '#000000', PAPER = '#ffffff', GREEN = '#79ebc0', DEEP = '#00a86b';
const PINK = '#ff6b9d', KRAFT = '#c79a63', KRAFT_DARK = '#a97f4e', GRID = '#edf3ef', MIST = '#f9fafb';

const canvas = createCanvas(W, H);
const ctx = canvas.getContext('2d');

async function main() {
const logo = await loadImage(fs.readFileSync(path.join(__dirname, '../app/views/shared/_logo.html.erb')));

// ---------- ground + grid ----------
ctx.fillStyle = PAPER;
ctx.fillRect(0, 0, W, H);
ctx.strokeStyle = GRID;
ctx.lineWidth = 2;
ctx.beginPath();
for (let x = 0.5; x < W; x += 44) { ctx.moveTo(x, 0); ctx.lineTo(x, H); }
for (let y = 0.5; y < H; y += 44) { ctx.moveTo(0, y); ctx.lineTo(W, y); }
ctx.stroke();

// ---------- base bar ----------
const BASE_Y = H - 78;
ctx.fillStyle = DEEP;
ctx.fillRect(0, BASE_Y, W, 78);
ctx.fillStyle = GREEN;
ctx.fillRect(0, BASE_Y, W, 8);
const barLogoH = 38, barLogoW = barLogoH * 456.039 / 149.71;
for (let i = 0; i < 3; i++) ctx.drawImage(logo, 160 + i * 440 - barLogoW / 2, BASE_Y + 21, barLogoW, barLogoH);

// ---------- block drawing (same shapes as the game) ----------
const BLOCK_H = 62;
function blockStyle(level) {
  const kind = ['cup', 'box', 'bowl'][level % 3];
  const color = [KRAFT, PAPER, GREEN][level % 3];
  return { kind, color };
}
function drawBlock(x, y, w, level) {
  const { kind, color } = blockStyle(level);
  ctx.save();
  ctx.lineWidth = 4;
  ctx.lineJoin = 'round';
  ctx.strokeStyle = INK;
  ctx.fillStyle = INK;
  ctx.fillRect(x + 3, y + 7, w, BLOCK_H);
  ctx.fillStyle = color;
  if (kind === 'cup') {
    const taper = 13;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + w, y);
    ctx.lineTo(x + w - taper, y + BLOCK_H);
    ctx.lineTo(x + taper, y + BLOCK_H);
    ctx.closePath();
    ctx.fill(); ctx.stroke();
    ctx.fillStyle = PINK;
    const bandY = y + BLOCK_H * 0.38;
    ctx.beginPath();
    ctx.moveTo(x + taper * 0.4, bandY);
    ctx.lineTo(x + w - taper * 0.4, bandY);
    ctx.lineTo(x + w - taper * 0.55, bandY + 16);
    ctx.lineTo(x + taper * 0.55, bandY + 16);
    ctx.closePath();
    ctx.fill(); ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(x, y + 10); ctx.lineTo(x + w, y + 10);
    ctx.stroke();
  } else if (kind === 'box') {
    ctx.fillRect(x, y, w, BLOCK_H);
    ctx.strokeRect(x, y, w, BLOCK_H);
    ctx.fillStyle = DEEP;
    const tw = 26;
    ctx.fillRect(x + w / 2 - tw / 2, y, tw, BLOCK_H);
    ctx.strokeRect(x + w / 2 - tw / 2, y, tw, BLOCK_H);
    ctx.beginPath();
    ctx.moveTo(x, y + BLOCK_H / 2); ctx.lineTo(x + w / 2 - tw / 2, y + BLOCK_H / 2);
    ctx.moveTo(x + w / 2 + tw / 2, y + BLOCK_H / 2); ctx.lineTo(x + w, y + BLOCK_H / 2);
    ctx.stroke();
  } else {
    const r = 18;
    ctx.beginPath();
    ctx.moveTo(x, y + 13);
    ctx.lineTo(x + w, y + 13);
    ctx.lineTo(x + w, y + BLOCK_H - r);
    ctx.arcTo(x + w, y + BLOCK_H, x + w - r, y + BLOCK_H, r);
    ctx.lineTo(x + r, y + BLOCK_H);
    ctx.arcTo(x, y + BLOCK_H, x, y + BLOCK_H - r, r);
    ctx.closePath();
    ctx.fill(); ctx.stroke();
    ctx.fillStyle = PINK;
    ctx.fillRect(x - 4, y, w + 8, 15);
    ctx.strokeRect(x - 4, y, w + 8, 15);
  }
  ctx.restore();
}

// ---------- tower ----------
const towerCX = 930, towerW = 250;
const jitter = [0, -14, 9, -6, 12, -10];
for (let i = 0; i < 6; i++) {
  drawBlock(towerCX - towerW / 2 + jitter[i], BASE_Y - BLOCK_H * (i + 1), towerW, i);
}
// swinging cup + arm (about to drop, slightly off-centre from the tower)
const armX = 1005, swingY = 58;
ctx.strokeStyle = INK;
ctx.lineWidth = 4;
ctx.beginPath();
ctx.moveTo(armX, 0);
ctx.lineTo(armX, swingY - 2);
ctx.stroke();
ctx.fillStyle = PINK;
ctx.beginPath();
ctx.roundRect(armX - 16, swingY - 14, 32, 15, 7);
ctx.fill(); ctx.stroke();
drawBlock(armX - towerW / 2, swingY, towerW, 0);

// confetti sprinkles
const conf = [[640, 90], [700, 210], [1120, 150], [1060, 320], [660, 380], [1150, 470], [615, 500]];
conf.forEach(([x, y], i) => {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate((i * 47 % 90) / 57);
  ctx.fillStyle = [GREEN, PINK, DEEP, KRAFT][i % 4];
  ctx.fillRect(-9, -6, 18, 12);
  ctx.restore();
});

// ---------- left copy panel ----------
ctx.textAlign = 'left';
ctx.textBaseline = 'alphabetic';

// hero lockup: the afida logo over the game title
const heroW = 385, heroH = heroW * 149.71 / 456.039;
ctx.drawImage(logo, 66, 100, heroW, heroH);
ctx.font = '108px Fredoka Medium';
const grad = ctx.createLinearGradient(66, 260, 480, 340);
grad.addColorStop(0, DEEP);
grad.addColorStop(1, '#3ecf9a');
ctx.fillStyle = grad;
ctx.fillText('Stack', 66, 348);

// tagline
ctx.fillStyle = INK;
ctx.font = '33px Fredoka';
ctx.fillText('Quality packaging supplies.', 70, 412);
ctx.fillText('Stacked recklessly high.', 70, 456);

// prize pill
ctx.fillStyle = INK;
ctx.beginPath();
ctx.roundRect(70 + 5, 494 + 6, 400, 62, 31);
ctx.fill();
ctx.fillStyle = GREEN;
ctx.beginPath();
ctx.roundRect(70, 494, 400, 62, 31);
ctx.fill();
ctx.lineWidth = 4;
ctx.strokeStyle = INK;
ctx.stroke();
ctx.fillStyle = INK;
ctx.font = '30px Fredoka Medium';
ctx.textAlign = 'left';
ctx.fillText('STACK 15', 116, 535);
ctx.fillStyle = DEEP;
ctx.fillText('5% OFF', 314, 535);
// hand-drawn arrow (Fredoka has no U+2192)
ctx.strokeStyle = INK;
ctx.lineWidth = 5;
ctx.lineCap = 'round';
ctx.beginPath();
ctx.moveTo(258, 524);
ctx.lineTo(294, 524);
ctx.moveTo(282, 512);
ctx.lineTo(296, 524);
ctx.lineTo(282, 536);
ctx.stroke();

fs.writeFileSync(path.join(__dirname, '../public/game/og.png'), canvas.toBuffer('image/png'));
console.log('written', fs.statSync(path.join(__dirname, '../public/game/og.png')).size, 'bytes');
}
main();
