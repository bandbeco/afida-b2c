# The Afida Stack arcade cabinet at /game. A real Rails page (CSRF, Vite
# assets, the monthly board on first paint) so the JSON endpoints can be
# ordinary forgery-protected actions instead of a static-file workaround.
class GamesController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :set_current_cart, :set_nav_categories
  layout "game"

  def show
    @board = Game.board.merge(
      token: Game::VerifiedRun.issue_token,
      win_score: Game::PromoCodes::BASE_WIN,
      invited_win_score: Game::PromoCodes::INVITED_WIN
    )
  end
end
