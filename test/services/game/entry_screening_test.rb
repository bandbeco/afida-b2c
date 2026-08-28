require "test_helper"

class Game::EntryScreeningTest < ActiveSupport::TestCase
  def screening(overrides = {})
    Game::EntryScreening.new(**{
      name: "Laurent",
      instagram_handle: "the.roastery",
      score: 12,
      perfect_ratio: 0.2,
      current_best: 15,
      recent_from_ip: 1
    }.merge(overrides))
  end

  test "an ordinary entry is clean" do
    subject = screening

    assert subject.clean?
    assert_empty subject.flags
  end

  test "profanity in the name is flagged" do
    assert_includes screening(name: "shithead").flags, "profanity"
  end

  test "leetspeak and separators do not hide profanity" do
    assert_includes screening(name: "sh1t.head").flags, "profanity"
    assert_includes screening(instagram_handle: "f_u_c_k_er").flags, "profanity"
  end

  test "posing as the brand or staff is flagged" do
    assert_includes screening(name: "Afida Team").flags, "impersonation"
    assert_includes screening(instagram_handle: "afida_official").flags, "impersonation"
    assert_includes screening(name: "admin").flags, "impersonation"
  end

  test "a score at or above the ceiling is flagged" do
    assert_includes screening(score: 40).flags, "high_score"
    assert screening(score: 39, current_best: 35).clean?
  end

  test "doubling the monthly best is flagged once the board is established" do
    assert_includes screening(score: 30, current_best: 12).flags, "outlier_score"
    # early-month noise: a small best doubled is not suspicious
    assert screening(score: 12, current_best: 5).clean?
    # no board yet, nothing to compare against
    assert screening(score: 30, current_best: nil, perfect_ratio: 0.2).clean?
  end

  test "a long run of near-total perfects is flagged" do
    assert_includes screening(score: 25, perfect_ratio: 0.95, current_best: 50).flags, "perfect_run"
    assert screening(score: 25, perfect_ratio: 0.6, current_best: 50).clean?
    # short runs can legitimately be all perfects
    assert screening(score: 8, perfect_ratio: 1.0).clean?
  end

  test "a burst of submissions from one address is flagged" do
    assert_includes screening(recent_from_ip: 5).flags, "burst"
    assert screening(recent_from_ip: 4).clean?
  end

  test "multiple problems yield multiple flags" do
    flags = screening(name: "fuck", score: 60).flags

    assert_includes flags, "profanity"
    assert_includes flags, "high_score"
  end
end
