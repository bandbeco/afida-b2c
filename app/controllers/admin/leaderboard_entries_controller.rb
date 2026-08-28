class Admin::LeaderboardEntriesController < Admin::ApplicationController
  def index
    @entries = LeaderboardEntry.order(month: :desc).best_first
  end

  def approve
    moderate("approved")
  end

  def reject
    moderate("rejected")
  end

  private

  def moderate(status)
    entry = LeaderboardEntry.find(params[:id])
    entry.update!(status: status)
    redirect_to admin_leaderboard_entries_path, notice: "Entry #{status}."
  end
end
