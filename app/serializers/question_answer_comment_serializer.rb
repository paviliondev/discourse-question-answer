# frozen_string_literal: true

class QuestionAnswerCommentSerializer < ApplicationSerializer
  attributes :id,
             :user_id,
             :name,
             :username,
             :created_at,
             :raw,
             :cooked

  def name
    object.user.name
  end

  def username
    object.user.username
  end
end
