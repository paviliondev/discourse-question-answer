Fabricator(:comment, from: :post) do
  reply_to_post_number
end
