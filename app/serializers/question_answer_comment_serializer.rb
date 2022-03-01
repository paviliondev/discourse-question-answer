# frozen_string_literal: true

class QuestionAnswerCommentSerializer < ApplicationSerializer
  attributes :id,
             :user_id,
             :name,
             :username,
             :created_at,
             :raw,
             :cooked,
             :qa_vote_count,
             :user_voted

  attr_accessor :comments_user_voted

  def name
    object.user.name
  end

  def username
    object.user.username
  end

  def user_voted
    if @comments_user_voted
      @comments_user_voted[object.id]
    else
      object.votes.exists?(user: scope.user)
    end
  end
end
