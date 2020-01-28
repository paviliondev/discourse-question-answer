require_dependency 'post_action_user_serializer'

module QuestionAnswer
  class VoterSerializer < PostActionUserSerializer
    def post_url
      nil
    end
  end
end
