# frozen_string_literal: true

class QuestionAnswerVote < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
end
