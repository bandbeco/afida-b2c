// Generates public/game/og.png (1200x630 social card for The Afida Stack).
// Run: npm i --no-save @napi-rs/canvas && node script/game_og_image.js
// Arcade-cabinet look: CRT ground, phosphor glow, scanlines over everything.
const { createCanvas, loadImage, GlobalFonts } = require('@napi-rs/canvas');
const fs = require('fs');

const path = require('path');
GlobalFonts.registerFromPath(path.join(__dirname, 'fonts/PressStart2P-Regular.ttf'), 'Press Start 2P');
GlobalFonts.registerFromPath(path.join(__dirname, 'fonts/VT323-Regular.ttf'), 'VT323');

const W = 1200, H = 630;
const INK = '#000000', PAPER = '#ffffff', GREEN = '#79ebc0', DEEP = '#00a86b';
const PINK = '#ff6b9d', KRAFT = '#c79a63';
const CRT = '#06130d', BASE_FILL = '#0b2015', ARM = '#2f5f49', GRID = '#10281c', MUTED = '#79a58f';

const canvas = createCanvas(W, H);
const ctx = canvas.getContext('2d');

function glowText(text, x, y, color, blur) {
  ctx.save();
  ctx.shadowColor = color;
  ctx.shadowBlur = blur;
  ctx.fillStyle = color;
  ctx.fillText(text, x, y);
  ctx.restore();
}

async function main() {
const logo = await loadImage(fs.readFileSync(path.join(__dirname, '../app/views/shared/_logo.html.erb')));

// ---------- CRT ground + dim phosphor grid ----------
ctx.fillStyle = CRT;
ctx.fillRect(0, 0, W, H);
ctx.strokeStyle = GRID;
ctx.lineWidth = 2;
ctx.beginPath();
for (let x = 0.5; x < W; x += 44) { ctx.moveTo(x, 0); ctx.lineTo(x, H); }
for (let y = 0.5; y < H; y += 44) { ctx.moveTo(0, y); ctx.lineTo(W, y); }
ctx.stroke();

// ---------- base platform ----------
const BASE_Y = H - 78;
ctx.fillStyle = BASE_FILL;
ctx.fillRect(0, BASE_Y, W, 78);
ctx.fillStyle = GREEN;
ctx.fillRect(0, BASE_Y, W, 8);

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
ctx.strokeStyle = ARM;
ctx.lineWidth = 4;
ctx.beginPath();
ctx.moveTo(armX, 0);
ctx.lineTo(armX, swingY - 2);
ctx.stroke();
ctx.fillStyle = PINK;
ctx.fillRect(armX - 16, swingY - 14, 32, 15);
drawBlock(armX - towerW / 2, swingY, towerW, 0);

// 2UP line to beat, crossing the tower like a duel link does in-game
ctx.save();
ctx.strokeStyle = PINK;
ctx.lineWidth = 4;
ctx.setLineDash([14, 10]);
ctx.beginPath();
ctx.moveTo(590, 252); ctx.lineTo(W, 252);
ctx.stroke();
ctx.setLineDash([]);
ctx.font = '16px "Press Start 2P"';
const badge = '2UP 0012';
const bw = ctx.measureText(badge).width + 28;
ctx.fillStyle = PINK;
ctx.fillRect(W - bw - 24, 252 - 40, bw, 32);
ctx.fillStyle = INK;
ctx.textAlign = 'center';
ctx.textBaseline = 'middle';
ctx.fillText(badge, W - bw / 2 - 24, 252 - 23);
ctx.restore();

// confetti sprinkles
const conf = [[640, 90], [700, 210], [1120, 150], [1060, 340], [660, 380], [1150, 470], [615, 480]];
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

// arcade HUD chrome
ctx.font = '20px "Press Start 2P"';
ctx.fillStyle = PINK;
ctx.fillText('1UP', 70, 64);
ctx.fillText('HI-SCORE', 290, 64);
glowText('0014', 160, 64, GREEN, 14);
ctx.fillStyle = KRAFT;
ctx.fillText('0015', 490, 64);

// hero lockup: the afida logo over the game title
const heroW = 340, heroH = heroW * 149.71 / 456.039;
ctx.save();
ctx.shadowColor = GREEN;
ctx.shadowBlur = 22;
ctx.drawImage(logo, 66, 104, heroW, heroH);
ctx.restore();
ctx.font = '92px "Press Start 2P"';
ctx.fillStyle = PINK;
ctx.fillText('STACK', 71, 333);
glowText('STACK', 66, 328, GREEN, 26);

// tagline
ctx.font = '42px VT323';
ctx.fillStyle = MUTED;
ctx.fillText('Quality packaging supplies.', 70, 392);
ctx.fillText('Stacked recklessly high.', 70, 434);

// bonus line
ctx.font = '26px "Press Start 2P"';
ctx.fillStyle = KRAFT;
ctx.fillText('STACK 15', 70, 500);
ctx.fillStyle = PAPER;
ctx.fillText('FOR', 316, 500);
glowText('£10 OFF', 410, 500, GREEN, 16);

// press start, sitting on the base platform like a credit line
ctx.font = '30px "Press Start 2P"';
glowText('PRESS START', 70, 601, GREEN, 18);

// ---------- CRT glass: scanlines + vignette ----------
ctx.fillStyle = 'rgba(0, 0, 0, 0.16)';
for (let y = 0; y < H; y += 3) ctx.fillRect(0, y, W, 1);
const vig = ctx.createRadialGradient(W / 2, H / 2, H * 0.45, W / 2, H / 2, H);
vig.addColorStop(0, 'rgba(0, 0, 0, 0)');
vig.addColorStop(1, 'rgba(0, 0, 0, 0.42)');
ctx.fillStyle = vig;
ctx.fillRect(0, 0, W, H);

fs.writeFileSync(path.join(__dirname, '../public/game/og.png'), canvas.toBuffer('image/png'));
console.log('written', fs.statSync(path.join(__dirname, '../public/game/og.png')).size, 'bytes');
}
main();
