# frozen_string_literal: true

require 'rails_helper'
require 'composer_messages_finder'

describe ComposerMessagesFinder do

  context '.check_sequential_replies' do
    fab!(:user) { Fabricate(:user) }
    fab!(:topic) { Fabricate(:topic) }
    fab!(:qa_topic) { Fabricate(:topic, subtype: Topic::QA_SUBTYPE) }

    before do
      SiteSetting.educate_until_posts = 4
      SiteSetting.sequential_replies_threshold = 2

      5.times do
        Fabricate(:post, topic: topic, user: user)
      end
    end

    it "notify user about sequential replies for regular topics" do
      finder = ComposerMessagesFinder.new(user, composer_action: 'reply', topic_id: topic.id)
      expect(finder.check_sequential_replies).to be_present
    end

    it "doesn't notify user about sequential replies for Q&A topics" do
      finder = ComposerMessagesFinder.new(user, composer_action: 'reply', topic_id: qa_topic.id)
      expect(finder.check_sequential_replies).to be_blank
    end
  end
end
