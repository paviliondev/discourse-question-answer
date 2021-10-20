# frozen_string_literal: true

class PostQuestionAnswerVote < ActiveRecord::Base
  belongs_to :post
end
