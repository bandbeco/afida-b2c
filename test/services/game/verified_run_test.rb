require "test_helper"

class Game::VerifiedRunTest < ActiveSupport::TestCase
  CANVAS = 400
  START_X = 108

  def token(issued_at: 30.seconds.ago)
    Game::VerifiedRun.token_verifier.generate({ "issued_at" => issued_at.to_i })
  end

  def verify(overrides = {})
    Game::VerifiedRun.from(**{
      token: token,
      canvas_width: CANVAS,
      xs: [ START_X ] * 5,
      ip: "127.0.0.1",
      ref: nil
    }.merge(overrides))
  end

  test "a timely token and a playable log is a verified run" do
    run = verify

    assert run.ok?
    assert_nil run.error
    assert_equal 5, run.replay.score
    assert_nil run.referrer
  end

  test "a missing or forged token is rejected" do
    assert_equal "invalid_token", verify(token: "forged").error
    assert_equal "invalid_token", verify(token: nil).error
    assert_not verify(token: "forged").ok?
  end

  test "a stale token is rejected" do
    run = verify(token: token(issued_at: 7.hours.ago))

    assert_equal "invalid_token", run.error
  end

  test "an impossible drop sequence is rejected" do
    run = verify(xs: [ START_X + 179 ])

    assert_equal "invalid_replay", run.error
    assert_nil run.replay
  end

  test "a run claimed faster than a human could play is rejected" do
    run = verify(token: token(issued_at: 1.second.ago), xs: [ START_X ] * 20)

    assert_equal "too_fast", run.error
  end

  test "an invite from another address is credited on the run" do
    host = LeaderboardEntry.create!(name: "Host", score: 9, submitter_ip: "9.9.9.9")

    run = verify(ref: host.ref_code, ip: "1.1.1.1")

    assert run.ok?
    assert_equal host, run.referrer
  end

  test "a self-invite is not credited" do
    host = LeaderboardEntry.create!(name: "Host", score: 9, submitter_ip: "127.0.0.1")

    run = verify(ref: host.ref_code, ip: "127.0.0.1")

    assert run.ok?
    assert_nil run.referrer
  end
end
