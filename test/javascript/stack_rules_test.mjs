import test from 'node:test'
import assert from 'node:assert/strict'
import { landing, playfield, effectiveTarget, claimError, nextMilestone } from '../../app/frontend/game/stack_rules.mjs'

test('the precision-boundary winning run retains its actual drop coordinates', () => {
  const drops = [...Array(9).fill(135), 142.004, 142.004, 200, 250, 300, 356]
  let block = { x: 135, w: 230 }
  for (const x of drops) {
    block = landing(block, x, 230)
    assert.equal(block.lost, false)
  }
  assert.equal(block.w, 11)
  assert.equal(drops[9], 142.004)
})

test('phones, desktop and zoom share identical game geometry', () => {
  for (const [width, height] of [[390, 844], [560, 900], [320, 400], [844, 390]]) {
    const field = playfield(width, height)
    assert.equal(field.width, 420)
    assert.equal(field.height, 740)
    assert.ok(field.scale > 0)
    assert.ok(field.width * field.scale <= width)
    assert.ok(field.height * field.scale <= height)
  }
})

test('only the server-resolved target controls the prize', () => {
  assert.equal(effectiveTarget({ effective_win_score: 15 }, '?ref=bogus'), 15)
  assert.equal(effectiveTarget({ effective_win_score: 12 }), 12)
})

test('claim errors distinguish a retryable failure from an expired round', () => {
  assert.match(claimError('invalid_token'), /expired/i)
  assert.match(claimError('rate_limited'), /wait/i)
  assert.match(claimError('sold_out'), /awarded/i)
  assert.match(claimError('mint_failed'), /saved|reserved/i)
})

test('progress changes into a claim action at the target', () => {
  assert.equal(nextMilestone(12, 15), '3 more for £10 off')
  assert.equal(nextMilestone(15, 15), 'Claim £10 voucher')
})
