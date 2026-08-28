require "test_helper"

class Game::StackReplayTest < ActiveSupport::TestCase
  # canvas 400 -> base width clamp(400 * 0.46, 120, 230) = 184, first block at x 108
  CANVAS = 400
  START_X = 108

  test "a run of perfect drops is valid and scores one per drop" do
    replay = Game::StackReplay.new(canvas_width: CANVAS, xs: [ START_X ] * 10)

    assert replay.valid?
    assert_equal 10, replay.score
  end

  test "drops within the perfect tolerance still count as perfect" do
    replay = Game::StackReplay.new(canvas_width: CANVAS, xs: [ START_X + 6, START_X + 6 ])

    assert replay.valid?
    assert_equal 2, replay.score
  end

  test "an offset drop is legal while it overlaps enough" do
    # dx 22: overlap 184 - 22 = 162, well above the minimum
    replay = Game::StackReplay.new(canvas_width: CANVAS, xs: [ START_X + 22, START_X + 22 ])

    assert replay.valid?
    assert_equal 2, replay.score
  end

  test "a drop with less than the minimum overlap is invalid" do
    # dx 179 leaves a 5px overlap; the game would have ended instead
    replay = Game::StackReplay.new(canvas_width: CANVAS, xs: [ START_X + 179 ])

    assert_not replay.valid?
    assert_nil replay.score
  end

  test "the trimmed width carries into later drops" do
    # After a 100px offset the block is 84 wide; another 100px offset can no
    # longer overlap enough, even though it would on a full-width block.
    replay = Game::StackReplay.new(canvas_width: CANVAS, xs: [ START_X + 100, START_X + 200 ])

    assert_not replay.valid?
  end

  test "perfect drops regrow the block but never past the base width" do
    # Trim to 162 wide, then stack perfects: width regrows by 4 per drop,
    # capped at 184. A later offset legal only at regrown width must pass.
    xs = [ START_X + 22 ] + [ START_X + 22 ] * 6
    replay = Game::StackReplay.new(canvas_width: CANVAS, xs: xs)

    assert replay.valid?
    assert_equal 7, replay.score
  end

  test "tracks the share of perfect drops for suspicion checks" do
    all_perfect = Game::StackReplay.new(canvas_width: CANVAS, xs: [ START_X ] * 10)
    assert_in_delta 1.0, all_perfect.perfect_ratio

    mixed = Game::StackReplay.new(canvas_width: CANVAS, xs: [ START_X, START_X + 22, START_X + 22, START_X + 50 ])
    assert_in_delta 0.5, mixed.perfect_ratio

    assert_nil Game::StackReplay.new(canvas_width: CANVAS, xs: [ START_X + 179 ]).perfect_ratio
  end

  test "a drop outside the canvas is invalid" do
    replay = Game::StackReplay.new(canvas_width: CANVAS, xs: [ CANVAS + 10 ])

    assert_not replay.valid?
  end

  test "an empty run is invalid" do
    assert_not Game::StackReplay.new(canvas_width: CANVAS, xs: []).valid?
  end

  test "non-numeric drops are invalid" do
    assert_not Game::StackReplay.new(canvas_width: CANVAS, xs: [ "boop" ]).valid?
    assert_not Game::StackReplay.new(canvas_width: CANVAS, xs: nil).valid?
  end

  test "an implausible canvas width is invalid" do
    assert_not Game::StackReplay.new(canvas_width: 10, xs: [ 0 ]).valid?
    # below the client's zoom-proof 420-unit minimum playfield
    assert_not Game::StackReplay.new(canvas_width: 300, xs: [ 0 ]).valid?
    assert_not Game::StackReplay.new(canvas_width: 99_999, xs: [ 0 ]).valid?
    assert_not Game::StackReplay.new(canvas_width: "wide", xs: [ 0 ]).valid?
  end

  test "a run longer than the score ceiling is invalid" do
    replay = Game::StackReplay.new(canvas_width: CANVAS, xs: [ START_X ] * 501)

    assert_not replay.valid?
  end
end
