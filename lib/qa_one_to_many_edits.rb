module OneToManyGuardianExtension
  def can_create_post_on_topic?(topic)
    post = self.try(:post_opts) || {}
    category = topic.category
    if category &&
      category.qa_enabled &&
      category.qa_one_to_many &&
      post.present? &&
      !post[:reply_to_post_number]
      return @user.id == topic.user_id
    end
    super(topic)
  end
end

class ::Guardian
  attr_accessor :post_opts
  prepend OneToManyGuardianExtension
end

module OneToManyPostCreatorExtension
  def valid?
    guardian.post_opts = @opts
    super
  end
end

class ::PostCreator
  prepend OneToManyPostCreatorExtension
end
