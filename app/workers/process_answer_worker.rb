class ProcessAnswerWorker < ApplicationWorker
  def perform(team_id, channel_id, ts, user_id, user_answer, response_url)
    return if team_id.blank? || channel_id.blank? || ts.blank? || user_id.blank? || user_answer.blank? || response_url.blank?

    team = Team.find_by(slack_id: team_id)
    game = team.games.find_by(channel: channel_id, ts: ts)

    logger.info "Received answer “#{user_answer}” for “#{game.question}” (game ID #{game.id}) from user #{user_id} in channel #{channel_id} in team #{team_id}"

    return if game.has_correct_answer?

    user = User.find_or_create_by(team_id: team.id, slack_id: user_id)

    answer = Answer.new(game: game, user: user, answer: user_answer)
    answer.save!

    logger.info "Answer “#{user_answer}” is #{answer.is_correct? ? 'correct' : 'incorrect'} for “#{game.question}”"

    if answer.is_correct?
      user.add_score(game.value)
    else
      user.deduct_score(game.value)
    end
    UpdateGameMessageWorker.perform_async(game.id, response_url)
  end
end
