# frozen_string_literal: true

describe TopicsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, subtype: Topic::QA_SUBTYPE) }
  fab!(:post) { create_post(topic: topic) }
  fab!(:qa_comment) { Fabricate(:qa_comment, raw: "this is a comment!", post: post) }

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

    it "includes QA comments for crawler view" do
      skip "temporarily disable crawler view test while the perf issues are being worked on"

      get "/t/#{topic.slug}/#{topic.id}.html"

      expect(response.status).to eq(200)

      crawler_html = response.body

      expect(crawler_html).to match(/<span class="qa-comment-cooked" itemprop="comment"><p>this is a comment!<\/p><\/span>/)
      expect(crawler_html).to match(/<span class="qa-answer-count-span" itemprop="answerCount">3<\/span>/)
    end
  end
end
