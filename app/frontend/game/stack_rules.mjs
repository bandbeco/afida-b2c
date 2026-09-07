// These rules use full-precision coordinates throughout, including the replay log.
// Keep the numerical constants aligned with Game::StackReplay.
export function landing(previous, x, baseWidth) {
  if (Math.abs(x - previous.x) <= 7) {
    const w = Math.min(previous.w + 4, baseWidth)
    return { x: previous.x - (w - previous.w) / 2, w, perfect: true, lost: false }
  }
  const left = Math.max(x, previous.x)
  const w = Math.min(x + previous.w, previous.x + previous.w) - left
  return { x: left, w, perfect: false, lost: w < 10 }
}

export function playfield(width, height) {
  return { width: 420, height: 740, scale: Math.min(width / 420, height / 740) }
}

export function effectiveTarget(boot) { return boot.effective_win_score }

export function nextMilestone(score, target) {
  return score >= target ? 'Claim £10 voucher' : `${target - score} more for £10 off`
}

export function claimError(reason) {
  return ({
    invalid_token: 'This round has expired. Refresh the page and play again.',
    invalid_replay: 'We could not verify this run. Please start another round.',
    below_target: 'This run has not reached the prize target yet.',
    rate_limited: 'Please wait an hour before trying again. Your round stays here.',
    sold_out: 'This month’s vouchers have all been awarded. You can still play for the crown.',
    mint_failed: 'Your voucher is reserved. Please try sending it again shortly.',
    invalid_email: 'Please enter a valid email address.',
    too_fast: 'Please wait a few seconds, then send your claim again.'
  })[reason] || 'Connection interrupted. Your run is still here; please try again.'
}
