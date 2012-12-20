require 'spec_helper'

describe Category do
  it { should have_many :questions }
  it { should have_many :categories }
  it { should belong_to :category }
  it { should belong_to :survey }
  it { should respond_to :content }

  it { should validate_presence_of :content }
end