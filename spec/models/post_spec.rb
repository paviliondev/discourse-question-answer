# frozen_string_literal: true

require 'rails_helper'

describe Post do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }
  fab!(:post) { Fabricate(:post, post_number: 2) }
  fab!(:tag) { Fabricate(:tag, name: 'qa') }
  let(:up) { QuestionAnswerVote.directions[:up] }
  let(:users) { [user1, user2, user3] }

  before do
    SiteSetting.qa_enabled = true
    SiteSetting.qa_tags = tag.name
    post.topic.tags << tag
  end

  context "validation" do
    it "ensures that comments are only nested one level deep" do
      post_2 = Fabricate(:post, reply_to_post_number: post.post_number, topic: post.topic)

      post_3 = Fabricate.build(:post,
        reply_to_post_number: post_2.post_number,
        topic: post.topic,
        user: post_2.user
      )

      expect(post_3.valid?).to eq(false)

      expect(post_3.errors.full_messages).to contain_exactly(
        I18n.t("post.qa.errors.depth")
      )
    end
  end

  it('should ignore vote_count') do
    expect(Post.ignored_columns.include?("vote_count")).to eq(true)
  end

  it 'should return last voted correctly' do
    freeze_time do
      expect(post.qa_last_voted(user1.id)).to eq(nil)

      QuestionAnswer::VoteManager.vote(post, user1)

      expect(post.qa_last_voted(user1.id)).to eq_time(Time.zone.now)
    end
  end

  it 'should return qa_can_vote correctly' do
    expect(post.qa_can_vote(user1.id)).to eq(true)

    QuestionAnswer::VoteManager.vote(post, user1)

    expect(post.qa_can_vote(user1.id)).to eq(false)
  end
end
