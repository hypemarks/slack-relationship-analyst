FactoryGirl.define do
    sequence(:text) { |n| "Example message #{n}" }
  factory :message do
    text
    s_type "message"
  end
end