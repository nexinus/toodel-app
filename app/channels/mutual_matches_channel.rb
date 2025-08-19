class MutualMatchesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "mutual_matches_#{current_user.id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
