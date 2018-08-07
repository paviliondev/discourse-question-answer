class SaveExistingPostVoteCountsToCustomFields < ActiveRecord::Migration[5.1]
  def up
    vote_totals = {}

    PostAction.where(post_action_type_id: 5).each do |action|
      if post = Post.find_by(id: action[:post_id])
        votes = post.vote_history

        votes.push(
          "direction": QuestionAnswer::Vote::UP,
          "action": QuestionAnswer::Vote::CREATE,
          "user_id": action[:user_id].to_s,
          "created_at": action[:created_at]
        )

        post.custom_fields['vote_history'] = votes.to_json
        post.save_custom_fields(true)
      end

      total = vote_totals[action[:post_id]]
      total = { count: 0, voted: [] } if total == nil

      total[:count] += 1

      voted = total[:voted]
      voted.push(action[:user_id])
      total[:voted] = voted

      vote_totals[action[:post_id]] = total
    end

    if vote_totals.any?
      vote_totals.each do |k, v|
        if post = Post.find_by(id: k)
          post.custom_fields['vote_history'] = post.vote_history.to_json
          post.custom_fields['vote_count'] = v[:count].to_i
          post.custom_fields['voted'] = v[:voted]
          post.save_custom_fields(true)
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
