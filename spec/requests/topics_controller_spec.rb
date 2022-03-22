# frozen_string_literal: true

describe TopicsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, subtype: Topic::QA_SUBTYPE) }
  fab!(:post) { create_post(topic: topic) }

  fab!(:answer) { create_post(topic: topic) }
  fab!(:answer_2) { create_post(topic: topic) }
  fab!(:answer_3) { create_post(topic: topic) }

  fab!(:vote) do
    QuestionAnswer::VoteManager.vote(answer_2, user, direction: QuestionAnswerVote.directions[:up])
  end

  fab!(:vote_2) do
    QuestionAnswer::VoteManager.vote(answer, user, direction: QuestionAnswerVote.directions[:down])
  end

  before do
    SiteSetting.qa_enabled = true
  end

  describe '#show' do
    it 'orders posts by number of votes for a Q&A topic' do
      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)

      payload = response.parsed_body

      expect(payload["post_stream"]["posts"].map { |p| p["id"] }).to eq([post.id, answer_2.id, answer_3.id, answer.id])
    end

    it "orders posts by date of creation when 'activity' filter is provided" do
      get "/t/#{topic.id}.json?filter=#{TopicView::ACTIVITY_FILTER}"

      expect(response.status).to eq(200)

      payload = response.parsed_body

      expect(payload["post_stream"]["posts"].map { |p| p["id"] }).to eq([post.id, answer.id, answer_2.id, answer_3.id])
    end
  end
end
