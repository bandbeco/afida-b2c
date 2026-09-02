(() => {
  'use strict';

  // ---------- Constants ----------
  const INK = '#000000';
  const PAPER = '#ffffff';
  const GREEN = '#79ebc0';
  const DEEP = '#00a86b';
  const PINK = '#ff6b9d';
  const KRAFT = '#c79a63';
  const KRAFT_DARK = '#a97f4e';
  const CRT = '#06130d';   // near-black with a green cast, the screen ground
  const BASE_FILL = '#0b2015';
  const ARM = '#2f5f49';
  const GRID = '#10281c';
  const PIXEL_FONT = '"Press Start 2P", monospace';
  const BLOCK_H = 46;
  const MIN_OVERLAP = 10;
  const PERFECT_TOL = 7;
  const PERFECT_GROWTH = 4;
  const BASE_MIN_W = 120;
  const BASE_MAX_W = 230;
  const BASE_RATIO = 0.46;
  const BASE_H = 78;
  const SWING_Y = 96;

  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ---------- Quips (afida's brand voice: dry, self-deprecating, trade-proud) ----------
  const QUIPS = {
    perfect: [
      'Flawless. Very us.',
      'Not a millimetre wasted.',
      'The Ritz would take that one.',
      'Dispatched with precision.',
      'Crisp as a new pizza box.',
      'Textbook. We’d sample that.',
      'Next-day delivery energy.'
    ],
    streak: [
      'steady on.',
      'showing off now.',
      'save some for the Marriott.',
      'you’ve done this before.',
      'this is getting glamorous.',
      'someone wants a trade account.'
    ],
    trim: [
      'Bit wonky. It ships anyway.',
      'Trimmed. Offcut’s compostable.',
      'Close enough for a Tuesday.',
      'Our courier has seen worse.',
      'That edge is a free sample now.',
      'Less glamorous than it sounds.',
      'Wobbly. Charming, though.',
      'The recycling bin thanks you.',
      'We’ll call it artisanal.'
    ],
    over: [
      'Gravity: 1. Packaging: 0.',
      'All compostable, thankfully.',
      'It outlasted our first business plan.',
      'We don’t insure towers.',
      'The warehouse has seen tidier.',
      'Somewhere, a forklift sighs.'
    ],
    win: [
      'The Ritz is asking for your number.',
      'Two mates with a box of straws salute you.',
      'Right, you’re hired.',
      'Put it on your CV. We would.',
      'Stacked it. Nailed it. Discounted it.'
    ]
  };
  const lastQuip = {};
  function quip(pool) {
    const list = QUIPS[pool];
    let i;
    do { i = Math.floor(Math.random() * list.length); } while (list.length > 1 && i === lastQuip[pool]);
    lastQuip[pool] = i;
    return list[i];
  }

  // ---------- Storage (fails soft in private windows) ----------
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch {} }
  };

  // ---------- DOM ----------
  const $ = id => document.getElementById(id);
  let boot = {};
  try {
    const el = $('game-board');
    if (el && el.textContent.trim()) boot = JSON.parse(el.textContent);
  } catch {}
  const BASE_WIN = boot.win_score;
  const INVITED_WIN = boot.invited_win_score;
  const canvas = $('game'), ctx = canvas.getContext('2d');
  // Warm up the pixel font so canvas text (quips, 2UP label) never falls back
  if (document.fonts) document.fonts.load('8px "Press Start 2P"');
  const hud = $('hud'), scoreEl = $('score'), hiEl = $('hiScore'), prizePill = $('prizePill');
  // Arcade scores wear leading zeros
  const pad = n => String(n).padStart(4, '0');
  const toastEl = $('toast'), menuEl = $('menu'), overEl = $('over');
  const challengeBanner = $('challengeBanner');

  // ---------- Challenge params ----------
  const params = new URLSearchParams(location.search);
  const beatScore = Math.min(999, parseInt(params.get('beat'), 10) || 0);
  const rivalName = (params.get('by') || '').replace(/[<>&"']/g, '').slice(0, 14).trim();
  // My shareable referral code (earned with the first board submission), and
  // the code of whoever invited me here. Arriving via an invite lowers the
  // prize threshold — the link is worth something to the person receiving it.
  let myCode = null;
  try { myCode = localStorage.getItem('afidaStackRefCode') || null; } catch {}
  let inviterCode = (params.get('ref') || '').toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 12) || null;
  if (inviterCode && inviterCode === myCode) inviterCode = null;
  const winScore = inviterCode ? INVITED_WIN : BASE_WIN;

  // Haptics for phones that support it (silently ignored elsewhere)
  function buzz(pattern) {
    if (reducedMotion) return;
    try { if (navigator.vibrate) navigator.vibrate(pattern); } catch {}
  }

  // ---------- Sound ----------
  let audio = null;
  let muted = store.get('afidaStackMuted') === '1';
  const muteBtn = $('muteBtn');
  const drawMute = () => { muteBtn.textContent = muted ? '×' : '♪'; };
  drawMute();
  muteBtn.addEventListener('click', e => {
    e.stopPropagation();
    muted = !muted;
    store.set('afidaStackMuted', muted ? '1' : '0');
    drawMute();
  });
  function beep(freq, dur, type, vol, when) {
    if (muted) return;
    try {
      audio = audio || new (window.AudioContext || window.webkitAudioContext)();
      if (audio.state === 'suspended') audio.resume();
      const t0 = audio.currentTime + (when || 0);
      const osc = audio.createOscillator(), gain = audio.createGain();
      osc.type = type || 'square';
      osc.frequency.setValueAtTime(freq, t0);
      gain.gain.setValueAtTime(vol || 0.08, t0);
      gain.gain.exponentialRampToValueAtTime(0.001, t0 + dur);
      osc.connect(gain).connect(audio.destination);
      osc.start(t0); osc.stop(t0 + dur);
    } catch {}
  }
  const sfx = {
    drop: () => beep(240, 0.08, 'square', 0.05),
    land: () => { beep(150, 0.12, 'triangle', 0.12); buzz(8); },
    perfect: () => { beep(660, 0.09, 'square', 0.07); beep(880, 0.12, 'square', 0.07, 0.07); buzz(18); },
    win: () => { [523, 659, 784, 1047].forEach((f, i) => beep(f, 0.16, 'square', 0.08, i * 0.11)); buzz([30, 40, 60]); },
    over: () => { beep(220, 0.18, 'sawtooth', 0.07); beep(150, 0.3, 'sawtooth', 0.07, 0.15); buzz(50); }
  };

  // ---------- Canvas sizing ----------
  // The game runs in virtual units with a minimum playfield of 420x640: when
  // the viewport is smaller (tiny phone, browser zoomed in) the scene renders
  // scaled down instead of shrinking the fall gap and swing travel. Zooming
  // changes how big the game looks, never how hard it is.
  const MIN_VW = 420, MIN_VH = 640;
  let W = 0, H = 0, viewScale = 1;
  function resize() {
    const dpr = Math.min(devicePixelRatio || 1, 2);
    const cw = canvas.clientWidth, ch = canvas.clientHeight;
    viewScale = Math.min(cw / MIN_VW, ch / MIN_VH, 1);
    W = cw / viewScale;
    H = ch / viewScale;
    canvas.width = Math.round(cw * dpr);
    canvas.height = Math.round(ch * dpr);
    ctx.setTransform(dpr * viewScale, 0, 0, dpr * viewScale, 0, 0);
  }
  addEventListener('resize', resize);
  resize();

  // ---------- Game state ----------
  let state = 'menu'; // menu | play | drop | tumble | over
  let stack = [];     // {x, w, level}
  let swing = { phase: 0, x: 0, w: 0 };
  let falling = null; // {x, y, w, vy, level} — y is the block's BOTTOM edge in screen space
  let debris = [];    // sliced offcuts + the fatal piece
  let particles = [];
  let confetti = [];
  let floaters = []; // quips rising off freshly-landed blocks
  let score = 0, combo = 0, unlocked = false;
  let cam = 0, camTarget = 0, shake = 0, overAt = 0;
  let best = parseInt(store.get('afidaStackBest'), 10) || 0;
  // Replay log for leaderboard verification: canvas width at game start plus
  // the left edge of every landed drop. The server re-runs the slice math.
  let dropLog = [], roundW = 0, roundBaseW = 0;

  function baseW() { return Math.max(BASE_MIN_W, Math.min(W * BASE_RATIO, BASE_MAX_W)); }
  function speedFor(n) { return 1.9 + Math.min(n * 0.075, 2.3); }
  // Replay is committed to roundW at startGame. Live W still drives drawing;
  // drop x must stay in the round's coordinate system or a rotate invalidates it.
  function fieldW() {
    return (state === 'play' || state === 'drop' || state === 'tumble') && roundW ? roundW : W;
  }
  function ampFor(w) { return (fieldW() - w) / 2 - 12; }
  function towerTopWorldY(n) { return BASE_H + n * BLOCK_H; }
  // world y (up from shell floor) -> screen y
  function sy(worldY) { return H - (worldY - cam); }

  function startGame() {
    stack = []; debris = []; particles = []; confetti = []; floaters = [];
    score = 0; combo = 0; unlocked = false;
    cam = 0; camTarget = 0; shake = 0;
    dropLog = []; roundW = W; roundBaseW = baseW();
    const w = roundBaseW;
    stack.push({ x: (roundW - w) / 2, w, level: 0 });
    swing = { phase: Math.PI / 2, x: 0, w };
    falling = null;
    state = 'play';
    scoreEl.textContent = pad(0);
    hiEl.textContent = pad(best);
    prizePill.textContent = 'Bonus £10 at ' + winScore;
    prizePill.classList.remove('unlocked');
    hud.classList.add('playing');
    menuEl.classList.add('hidden');
    overEl.classList.add('hidden');
    // How-to lives in the game, not the menu: shown until the first-ever drop
    $('dropHint').classList.toggle('hidden', !!store.get('afidaStackDropped'));
  }

  function drop() {
    if (state !== 'play') return;
    store.set('afidaStackDropped', '1');
    $('dropHint').classList.add('hidden');
    falling = {
      x: swing.x - swing.w / 2,
      y: SWING_Y + BLOCK_H,
      w: swing.w, vy: 0,
      level: stack.length
    };
    state = 'drop';
    sfx.drop();
  }

  function resolveLanding() {
    const prev = stack[stack.length - 1];
    let x = falling.x, w = falling.w;
    const dx = x - prev.x;

    if (Math.abs(dx) <= PERFECT_TOL) {
      // Perfect: snap, tiny regrowth, streak (cap locked at round start so the
      // server replay stays exact even if the window resizes mid-game)
      x = prev.x;
      w = Math.min(prev.w + PERFECT_GROWTH, roundBaseW);
      x -= (w - prev.w) / 2;
      combo++;
      sfx.perfect();
      floatQuip(combo > 1 ? 'Perfect x' + combo + ' — ' + quip('streak') : quip('perfect'), x + w / 2, towerTopWorldY(falling.level) + BLOCK_H, GREEN);
      burst(x + w / 2, sy(towerTopWorldY(falling.level)) - BLOCK_H / 2, DEEP, 14);
    } else {
      const left = Math.max(x, prev.x);
      const right = Math.min(x + w, prev.x + prev.w);
      const overlap = right - left;
      if (overlap < MIN_OVERLAP) return gameOver();
      // Sliced offcut tumbles away
      const cutW = w - overlap;
      if (cutW > 2) {
        const cutX = dx > 0 ? left + overlap : x;
        debris.push({
          x: cutX, y: sy(towerTopWorldY(falling.level)) - BLOCK_H, w: cutW, h: BLOCK_H,
          vx: dx > 0 ? 90 : -90, vy: -60, vr: (dx > 0 ? 1 : -1) * 2.4, rot: 0,
          level: falling.level
        });
      }
      x = left; w = overlap;
      combo = 0;
      sfx.land();
      floatQuip(quip('trim'), x + w / 2, towerTopWorldY(falling.level) + BLOCK_H, PAPER);
    }

    dropLog.push(Math.round(falling.x * 100) / 100);
    stack.push({ x, w, level: falling.level });
    falling = null;
    score++;
    scoreEl.textContent = pad(score);
    if (!reducedMotion) shake = 5;
    if (score >= winScore && !unlocked) unlockPrize();
    if (score > best) { best = score; store.set('afidaStackBest', String(best)); hiEl.textContent = pad(best); }

    camTarget = Math.max(0, towerTopWorldY(stack.length) - H * 0.62);
    swing = { phase: swing.phase, x: swing.x, w };
    state = 'play';
  }

  function unlockPrize() {
    unlocked = true;
    prizePill.textContent = '£10 banked';
    prizePill.classList.add('unlocked');
    toast('£10 off unlocked!', true);
    sfx.win();
    if (!reducedMotion) {
      for (let i = 0; i < 80; i++) {
        confetti.push({
          x: Math.random() * W, y: -20 - Math.random() * H * 0.5,
          vy: 120 + Math.random() * 160, vx: (Math.random() - 0.5) * 60,
          rot: Math.random() * 6.28, vr: (Math.random() - 0.5) * 8,
          s: 5 + Math.random() * 7,
          color: [GREEN, PINK, DEEP, KRAFT][i % 4]
        });
      }
    }
  }

  function gameOver() {
    // The fatal piece tumbles off
    debris.push({
      x: falling.x, y: falling.y - BLOCK_H, w: falling.w, h: BLOCK_H,
      vx: 40, vy: 30, vr: 3, rot: 0, level: falling.level
    });
    falling = null;
    state = 'tumble';
    overAt = performance.now() + 900;
    if (!reducedMotion) shake = 10;
    sfx.over();
  }

  // One hero per outcome: the prize when the run won, the challenge share
  // when the score is worth bragging about, and a plain "go again" for a
  // short one. Everything else waits behind a collapsed fold.
  const BRAG_SCORE = 5;
  function showOverScreen() {
    state = 'over';
    hud.classList.remove('playing');
    const won = score >= winScore;
    const low = score < BRAG_SCORE;
    $('overTitle').textContent =
      won ? 'You win!' :
      score === best && score > 0 ? 'New hi-score' : 'Game over';
    $('overQuip').textContent = won ? quip('win') : quip('over');
    $('finalScore').textContent = pad(score);
    $('bestLine').textContent = 'Hi-score ' + pad(best) +
      (beatScore ? ' · 2UP ' + (rivalName || 'Rival') + ' ' + pad(beatScore) : '');
    $('prizeCard').classList.toggle('hidden', !unlocked);
    if (unlocked) resetWinClaim();

    const fold = $('challengeFold');
    fold.classList.toggle('hidden', low);
    fold.open = !won && !low;
    const pitch = $('sharePitch');
    pitch.classList.toggle('hidden', won || low);
    if (!won && !low) {
      pitch.textContent = beatScore && score > beatScore
        ? (rivalName || 'Your rival') + ' has been dealt with. Pick the next one.'
        : score + ' stacks and no witnesses. Fix that.';
    }
    $('againBtn').classList.toggle('ghost', !low);

    refreshPreview();
    prepareBoardCard();
    overEl.classList.remove('hidden');
  }

  // ---------- Toast ----------
  let toastTimer = 0;
  function toast(msg, pink) {
    toastEl.textContent = msg;
    toastEl.classList.toggle('pink', !!pink);
    toastEl.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('show'), 1400);
  }

  // ---------- Particles ----------
  function burst(x, y, color, n) {
    if (reducedMotion) return;
    for (let i = 0; i < n; i++) {
      const a = Math.random() * 6.28, sp = 60 + Math.random() * 140;
      particles.push({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 60, s: 3 + Math.random() * 4, life: 0.7, color });
    }
  }

  // Flavour quips emanate from the block that just landed: anchored to the
  // tower in world space, drifting upward with a slow fade, so they never
  // cover the landing zone or pull the eye away from it.
  const FLOAT_LIFE = 1.9, FLOAT_RISE = 54;
  function floatQuip(text, x, worldY, color) {
    // The pixel font is ASCII-only: swap curly quotes and em-dashes so the
    // canvas never renders tofu boxes.
    const ascii = text.replace(/’/g, "'").replace(/\s*—\s*/g, ' - ');
    floaters.push({ text: ascii, x, worldY, color, age: 0 });
  }

  // ---------- Drawing ----------
  // The tower cycles through Afida's actual catalogue: kraft hot cups,
  // kraft deli boxes, soup containers with lids.
  function blockStyle(level) {
    const kind = ['cup', 'box', 'bowl'][Math.floor(level / 5) % 3];
    const color = [KRAFT, PAPER, GREEN][level % 3];
    return { kind, color };
  }

  function drawBlock(x, y, w, level, rot, cx, cy) {
    const { kind, color } = blockStyle(level);
    ctx.save();
    if (rot) { ctx.translate(cx, cy); ctx.rotate(rot); ctx.translate(-cx, -cy); }
    ctx.lineWidth = 3;
    ctx.lineJoin = 'round';
    ctx.strokeStyle = INK;
    // chunky bottom shadow
    ctx.fillStyle = INK;
    ctx.fillRect(x + 2, y + 5, w, BLOCK_H);
    ctx.fillStyle = color;
    if (kind === 'cup') {
      const taper = Math.min(10, w * 0.12);
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + w, y);
      ctx.lineTo(x + w - taper, y + BLOCK_H);
      ctx.lineTo(x + taper, y + BLOCK_H);
      ctx.closePath();
      ctx.fill(); ctx.stroke();
      // sleeve band
      ctx.fillStyle = level % 3 === 2 ? PINK : level % 3 === 1 ? GREEN : PINK;
      const bandY = y + BLOCK_H * 0.38;
      ctx.beginPath();
      ctx.moveTo(x + taper * 0.4, bandY);
      ctx.lineTo(x + w - taper * 0.4, bandY);
      ctx.lineTo(x + w - taper * 0.55, bandY + 12);
      ctx.lineTo(x + taper * 0.55, bandY + 12);
      ctx.closePath();
      ctx.fill(); ctx.stroke();
      // lid line
      ctx.beginPath();
      ctx.moveTo(x, y + 8); ctx.lineTo(x + w, y + 8);
      ctx.stroke();
    } else if (kind === 'box') {
      ctx.fillRect(x, y, w, BLOCK_H);
      ctx.strokeRect(x, y, w, BLOCK_H);
      // tape stripe
      ctx.fillStyle = level % 3 === 0 ? GREEN : level % 3 === 2 ? PINK : DEEP;
      const tw = Math.min(18, w * 0.25);
      ctx.fillRect(x + w / 2 - tw / 2, y, tw, BLOCK_H);
      ctx.strokeRect(x + w / 2 - tw / 2, y, tw, BLOCK_H);
      // flap line
      ctx.beginPath();
      ctx.moveTo(x, y + BLOCK_H / 2); ctx.lineTo(x + w / 2 - tw / 2, y + BLOCK_H / 2);
      ctx.moveTo(x + w / 2 + tw / 2, y + BLOCK_H / 2); ctx.lineTo(x + w, y + BLOCK_H / 2);
      ctx.stroke();
    } else {
      // soup container: rounded-bottom tub with a lid
      const r = Math.min(14, w * 0.2);
      ctx.beginPath();
      ctx.moveTo(x, y + 10);
      ctx.lineTo(x + w, y + 10);
      ctx.lineTo(x + w, y + BLOCK_H - r);
      ctx.arcTo(x + w, y + BLOCK_H, x + w - r, y + BLOCK_H, r);
      ctx.lineTo(x + r, y + BLOCK_H);
      ctx.arcTo(x, y + BLOCK_H, x, y + BLOCK_H - r, r);
      ctx.closePath();
      ctx.fill(); ctx.stroke();
      // lid
      ctx.fillStyle = level % 3 === 1 ? PINK : level % 3 === 0 ? KRAFT_DARK : PAPER;
      ctx.fillRect(x - 3, y, w + 6, 12);
      ctx.strokeRect(x - 3, y, w + 6, 12);
    }
    ctx.restore();
  }

  function drawBase() {
    const y = sy(BASE_H);
    ctx.fillStyle = BASE_FILL;
    ctx.fillRect(0, y, W, BASE_H + 200);
    ctx.fillStyle = GREEN;
    ctx.fillRect(0, y, W, 6);
  }

  function drawRivalLine() {
    if (!beatScore) return;
    const y = sy(towerTopWorldY(beatScore));
    if (y < -30 || y > H + 30) return;
    ctx.save();
    ctx.strokeStyle = PINK;
    ctx.lineWidth = 3;
    ctx.setLineDash([10, 8]);
    ctx.beginPath();
    ctx.moveTo(0, y); ctx.lineTo(W, y);
    ctx.stroke();
    ctx.setLineDash([]);
    const label = '2UP ' + (rivalName || 'RIVAL').toUpperCase() + ' ' + beatScore;
    ctx.font = '8px ' + PIXEL_FONT;
    const tw = ctx.measureText(label).width + 18;
    ctx.fillStyle = PINK;
    ctx.fillRect(W - tw - 10, y - 26, tw, 22);
    ctx.fillStyle = INK;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(label, W - tw / 2 - 10, y - 14);
    ctx.restore();
  }

  function render(now) {
    ctx.clearRect(0, 0, W, H);
    // CRT ground + dim phosphor grid, offset by camera for depth
    ctx.fillStyle = CRT;
    ctx.fillRect(0, 0, W, H);
    ctx.strokeStyle = GRID;
    ctx.lineWidth = 1;
    const gs = 44, oy = cam % gs;
    ctx.beginPath();
    for (let gx = 0.5; gx < W; gx += gs) { ctx.moveTo(gx, 0); ctx.lineTo(gx, H); }
    for (let gy = oy + 0.5; gy < H; gy += gs) { ctx.moveTo(0, gy); ctx.lineTo(W, gy); }
    ctx.stroke();

    ctx.save();
    if (shake > 0.5) {
      ctx.translate((Math.random() - 0.5) * shake, (Math.random() - 0.5) * shake);
    }

    drawBase();
    drawRivalLine();

    // tower (gentle cosmetic sway when tall)
    const swayA = reducedMotion ? 0 : Math.min(stack.length / 40, 1) * 3;
    for (const b of stack) {
      const y = sy(towerTopWorldY(b.level)) - BLOCK_H;
      if (y > H + 60 || y < -60) continue;
      const sway = swayA * Math.sin(now / 900 + b.level * 0.25) * (b.level / Math.max(stack.length, 1));
      drawBlock(b.x + sway, y, b.w, b.level, 0, 0, 0);
    }

    // swinging block + dispenser arm (also runs as the menu's attract mode)
    if (state === 'play' || state === 'menu') {
      drawBlock(swing.x - swing.w / 2, SWING_Y, swing.w, stack.length, 0, 0, 0);
      ctx.strokeStyle = ARM;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(swing.x, 0); ctx.lineTo(swing.x, SWING_Y - 2);
      ctx.stroke();
      ctx.fillStyle = PINK;
      ctx.fillRect(swing.x - 13, SWING_Y - 11, 26, 12);
    }

    // falling block
    if (falling) drawBlock(falling.x, falling.y - BLOCK_H, falling.w, falling.level, 0, 0, 0);

    // debris
    for (const d of debris) {
      drawBlock(d.x, d.y, d.w, d.level, d.rot, d.x + d.w / 2, d.y + d.h / 2);
    }

    // particles
    for (const p of particles) {
      ctx.globalAlpha = Math.max(p.life / 0.7, 0);
      ctx.fillStyle = p.color;
      ctx.fillRect(p.x - p.s / 2, p.y - p.s / 2, p.s, p.s);
    }
    ctx.globalAlpha = 1;

    // confetti
    for (const c of confetti) {
      ctx.save();
      ctx.translate(c.x, c.y);
      ctx.rotate(c.rot);
      ctx.fillStyle = c.color;
      ctx.fillRect(-c.s / 2, -c.s / 2, c.s, c.s * 0.6);
      ctx.restore();
    }

    // rising quips
    if (floaters.length) {
      ctx.save();
      ctx.font = '8px ' + PIXEL_FONT;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'alphabetic';
      ctx.lineJoin = 'round';
      for (const f of floaters) {
        const t = f.age / FLOAT_LIFE;
        const rise = reducedMotion ? 0 : FLOAT_RISE * (1 - Math.pow(1 - t, 3));
        const y = sy(f.worldY) - 14 - rise;
        if (y < -20 || y > H + 20) continue;
        const half = ctx.measureText(f.text).width / 2;
        const fx = Math.min(Math.max(f.x, half + 8), W - half - 8);
        ctx.globalAlpha = t < 0.5 ? 1 : Math.max(0, 1 - (t - 0.5) / 0.5);
        ctx.strokeStyle = CRT;
        ctx.lineWidth = 4;
        ctx.strokeText(f.text, fx, y);
        ctx.fillStyle = f.color;
        ctx.fillText(f.text, fx, y);
      }
      ctx.restore();
    }

    ctx.restore();
  }

  // ---------- Main loop ----------
  let last = performance.now();
  function tick(now) {
    const dt = Math.min((now - last) / 1000, 0.05);
    last = now;

    if (state === 'play' || state === 'menu') {
      swing.phase += dt * (state === 'menu' ? 1.2 : speedFor(stack.length));
      swing.x = fieldW() / 2 + Math.sin(swing.phase) * ampFor(swing.w);
    }
    if (state === 'drop' && falling) {
      falling.vy += 2600 * dt;
      falling.y += falling.vy * dt;
      const targetY = sy(towerTopWorldY(falling.level));
      if (falling.y >= targetY) { falling.y = targetY; resolveLanding(); }
    }
    if (state === 'tumble' && performance.now() >= overAt) showOverScreen();

    cam += (camTarget - cam) * Math.min(dt * 6, 1);
    shake *= Math.pow(0.001, dt);

    for (const d of debris) {
      d.vy += 1800 * dt; d.x += d.vx * dt; d.y += d.vy * dt; d.rot += d.vr * dt;
    }
    debris = debris.filter(d => d.y < H + 200);
    for (const p of particles) {
      p.vy += 900 * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt;
    }
    particles = particles.filter(p => p.life > 0);
    for (const c of confetti) {
      c.y += c.vy * dt; c.x += c.vx * dt + Math.sin(c.y / 30) * 0.6; c.rot += c.vr * dt;
    }
    confetti = confetti.filter(c => c.y < H + 40);
    for (const f of floaters) f.age += dt;
    floaters = floaters.filter(f => f.age < FLOAT_LIFE);

    render(now);
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);

  // ---------- Input ----------
  canvas.addEventListener('pointerdown', drop);
  addEventListener('keydown', e => {
    if (e.code !== 'Space' && e.code !== 'Enter') return;
    if (document.activeElement && document.activeElement.tagName === 'INPUT') return;
    if (state === 'play') { e.preventDefault(); drop(); }
  });

  // ---------- Share ----------
  const nameInput = $('nameInput');
  const sharePreview = $('sharePreview');
  nameInput.value = store.get('afidaStackName') || '';
  function shareText() {
    const name = nameInput.value.replace(/[<>&"']/g, '').trim().slice(0, 14);
    store.set('afidaStackName', name);
    const url = new URL(location.origin + location.pathname);
    url.searchParams.set('beat', String(score));
    if (name) url.searchParams.set('by', name);
    if (myCode) url.searchParams.set('ref', myCode);
    const brag = score >= winScore
      ? `\u{1F964}\u{1F4E6} I stacked ${score} crates of eco-packaging and won £10 off at afida.com`
      : `\u{1F964}\u{1F4E6} I stacked ${score} on The Afida Stack before it all came down`;
    const gift = myCode ? '\nCrane’s greased for you — you win the £10 at 12.' : '';
    return `${brag}${gift}\nYour move: ${url.toString()}`;
  }
  function refreshPreview() {
    sharePreview.textContent = shareText();
    $('shareBonus').textContent = myCode
      ? 'You get £10 off when someone you share this with places their first order over £100. They get an easier win: £10 off at 12 stacks, not 15. Stack another £10 for each business that orders.'
      : 'Join the hi-score table to get a share link. You get £10 off each time someone you send it to places their first order over £100.';
  }
  nameInput.addEventListener('input', refreshPreview);

  // Clipboard API needs a secure context; fall back to execCommand elsewhere
  async function copyText(text) {
    try {
      if (navigator.clipboard) { await navigator.clipboard.writeText(text); return true; }
    } catch {}
    try {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.className = 'clipboard-stage';
      document.body.appendChild(ta);
      ta.select();
      const ok = document.execCommand('copy');
      ta.remove();
      return ok;
    } catch { return false; }
  }
  const copyShareBtn = $('copyShare');
  copyShareBtn.addEventListener('click', async () => {
    const text = shareText();
    if (await copyText(text)) {
      copyShareBtn.textContent = 'Copied!';
      setTimeout(() => { copyShareBtn.textContent = 'Copy challenge'; }, 1600);
    } else {
      prompt('Copy your challenge:', text);
    }
  });
  const shareBtn = $('shareBtn');
  if (navigator.share) shareBtn.classList.remove('hidden');
  shareBtn.addEventListener('click', async () => {
    try { await navigator.share({ text: shareText() }); } catch {}
  });
  // ---------- Prize claim ----------
  // The code exists only in Stripe and the claimant's inbox: the claim posts
  // the winning run's proof, the server re-verifies it, mints a unique
  // single-use code and emails it. Nothing shown here is worth scraping.
  function resetWinClaim() {
    $('winSent').classList.add('hidden');
    const btn = $('winEmailBtn');
    btn.disabled = false;
    btn.textContent = 'Send my code';
  }
  $('winEmail').value = store.get('afidaStackEmail') || '';
  $('winEmailRow').addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = $('winEmail').value.trim();
    if (!email) return;
    const btn = $('winEmailBtn');
    btn.disabled = true;
    btn.textContent = 'Sending…';
    try {
      const r = await fetch('/game/win_code', {
        method: 'POST',
        headers: jsonHeaders(),
        body: JSON.stringify({
          email,
          marketing: $('winOptIn').checked,
          token: lb.token,
          canvas_width: roundW,
          xs: dropLog,
          ref: inviterCode || undefined
        })
      });
      if (!r.ok) throw new Error(r.status);
      store.set('afidaStackEmail', email);
      const sent = $('winSent');
      sent.textContent = 'Sent to ' + email + ' — check your inbox.';
      sent.classList.remove('hidden');
      btn.disabled = false;
      btn.textContent = 'Send again';
    } catch {
      btn.disabled = false;
      btn.textContent = 'Try again';
    }
  });

  // ---------- Monthly leaderboard ----------
  // First paint carries the board in #game-board; GET /game/leaderboard
  // refreshes after a submission. POSTs send the Rails CSRF token.
  function jsonHeaders() {
    const headers = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
    const csrf = document.querySelector('meta[name="csrf-token"]');
    if (csrf) headers['X-CSRF-Token'] = csrf.content;
    return headers;
  }

  const lb = { ok: false, token: null, entries: [], month: '' };

  function applyBoard(d) {
    lb.ok = true;
    if (d.token && !lb.token) lb.token = d.token;
    lb.entries = d.entries || [];
    lb.month = d.month || '';
    renderBoard();
  }
  const igInput = $('igInput');
  igInput.value = store.get('afidaStackIG') || '';
  const lbEmail = $('lbEmail');
  lbEmail.value = store.get('afidaStackEmail') || '';

  async function fetchBoard() {
    try {
      const r = await fetch('/game/leaderboard', { headers: { 'Accept': 'application/json' } });
      if (!r.ok) throw new Error(r.status);
      applyBoard(await r.json());
    } catch {
      if (!lb.token) lb.ok = false;
    }
  }

  function readBootBoard() {
    if (boot.token || boot.entries) applyBoard(boot);
  }

  function daysUntilReset() {
    const now = new Date();
    const next = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    return Math.max(1, Math.ceil((next - now) / 86400000));
  }

  function fillBoard(list, limit) {
    list.textContent = '';
    for (const e of lb.entries.slice(0, limit)) {
      const li = document.createElement('li');
      const rank = document.createElement('span');
      rank.className = 'rank';
      rank.textContent = e.rank + '.';
      const who = document.createElement('span');
      who.className = 'who';
      who.textContent = e.name;
      if (e.instagram_handle) {
        who.append(' ');
        const a = document.createElement('a');
        a.href = 'https://instagram.com/' + encodeURIComponent(e.instagram_handle);
        a.rel = 'noopener nofollow ugc';
        a.target = '_blank';
        a.textContent = '@' + e.instagram_handle;
        who.append(a);
      }
      const pts = document.createElement('span');
      pts.className = 'pts';
      pts.textContent = e.score;
      li.append(rank, who, pts);
      list.append(li);
    }
  }

  function renderBoard() {
    if (!lb.ok) return;
    $('menuBoard').classList.remove('hidden');
    $('railScores').classList.remove('hidden');
    const lead = lb.entries[0];
    $('boardLead').textContent = lead
      ? 'Hi-score ' + pad(lead.score) + ' ' + lead.name
      : 'Hi-score table';
    const days = daysUntilReset();
    const reset = ' · resets in ' + days + (days === 1 ? ' day' : ' days');
    $('boardTitle').textContent = (lb.month || 'Top stackers') + reset;
    $('railBoardTitle').textContent = (lb.month || 'Top stackers') + reset;
    $('boardEmpty').classList.toggle('hidden', lb.entries.length > 0);
    $('railBoardEmpty').classList.toggle('hidden', lb.entries.length > 0);
    // the menu fold keeps a tight top 5; the desktop rail has room for all 10
    fillBoard($('boardList'), 5);
    fillBoard($('railBoardList'), 10);
  }

  function prepareBoardCard() {
    const fold = $('lbFold');
    fold.classList.toggle('hidden', !lb.ok || score < BRAG_SCORE);
    fold.open = false;
    $('lbForm').classList.remove('hidden');
    $('lbNote').classList.remove('hidden');
    $('lbResult').classList.add('hidden');
    $('lbSubmit').disabled = false;
    $('lbSubmit').textContent = 'Join the board';
  }

  $('lbSubmit').addEventListener('click', async () => {
    const btn = $('lbSubmit');
    btn.disabled = true;
    btn.textContent = 'Sending…';
    const handle = igInput.value.trim();
    store.set('afidaStackIG', handle);
    const email = lbEmail.value.trim();
    if (email && !/.+@.+\..+/.test(email)) {
      btn.disabled = false;
      btn.textContent = 'Join the board';
      const oops = $('lbResult');
      oops.textContent = 'That email looks off — fix it or clear it.';
      oops.classList.remove('hidden');
      return;
    }
    if (email) store.set('afidaStackEmail', email);
    try {
      const r = await fetch('/game/leaderboard', {
        method: 'POST',
        headers: jsonHeaders(),
        body: JSON.stringify({
          token: lb.token,
          name: (nameInput.value.trim() || 'Stacker').slice(0, 14),
          instagram_handle: handle,
          email: email || undefined,
          marketing: $('lbOptIn').checked || undefined,
          canvas_width: roundW,
          xs: dropLog,
          ref: inviterCode || undefined
        })
      });
      if (!r.ok) throw new Error(r.status);
      const d = await r.json();
      if (email) store.set('afidaStackBoardEmail', '1');
      if (d.ref_code && !myCode) {
        myCode = d.ref_code;
        store.set('afidaStackRefCode', myCode);
      }
      refreshPreview();
      $('lbForm').classList.add('hidden');
      $('lbNote').classList.add('hidden');
      const result = $('lbResult');
      result.textContent = 'You’re #' + d.rank + ' this month.' +
        (d.rank <= 10 ? ' On the board.' : ' Top 10 gets the glory — go again.');
      result.classList.remove('hidden');
      fetchBoard();
    } catch {
      btn.disabled = false;
      btn.textContent = 'Try again';
      const result = $('lbResult');
      result.textContent = 'Couldn’t verify that run — give it another go.';
      result.classList.remove('hidden');
    }
  });

  readBootBoard();
  fetchBoard();

  // ---------- Menu wiring ----------
  // Attract mode: a little demo tower stands behind the menu while the
  // dispenser swings above it, so the first thing a visitor sees is the game.
  function buildDemoTower() {
    const w = baseW();
    const jitter = [ 0, -10, 7, -5 ];
    stack = jitter.map((j, i) => ({ x: (W - w) / 2 + j, w, level: i }));
    swing = { phase: Math.PI / 2, x: W / 2, w };
  }
  buildDemoTower();
  addEventListener('resize', () => { if (state === 'menu') buildDemoTower(); });

  $('winTarget').textContent = winScore;
  $('railWinTarget').textContent = winScore;
  if (inviterCode) $('refBoost').classList.remove('hidden');
  if (beatScore > 0) {
    challengeBanner.textContent =
      '2UP ' + (rivalName || 'A rival') + ' stacked ' + beatScore + '. Your move.';
    challengeBanner.classList.remove('hidden');
  }
  $('playBtn').addEventListener('click', startGame);
  $('againBtn').addEventListener('click', startGame);
})();
