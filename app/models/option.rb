class Option < ActiveRecord::Base
  belongs_to :question
  has_many :questions, :foreign_key => :parent_id, :dependent => :destroy
  has_many :categories, :foreign_key => :parent_id, :dependent => :destroy
  attr_accessible :content, :question_id, :order_number
  validates_uniqueness_of :order_number, :scope => :question_id
  validates_presence_of :content, :question_id
  default_scope :order => 'order_number'

  def duplicate(survey_id)
    option = self.dup
    option.questions << questions.map { |question| question.duplicate(survey_id) }
    option.categories << categories.map { |category| category.duplicate(survey_id) }
    option.save(:validate => false)
    option
  end

  def elements
    (questions + categories).sort_by(&:order_number)
  end

  def as_json(opts={})
    super(opts).merge({:questions => questions.map { |question| question.json(:methods => :type) }})
  end

  def report_data
    Answer.joins(:response).where("answers.question_id = ? AND responses.status = 'complete' AND answers.content = ?", question_id, content).count
  end

  def categories_with_questions
    categories.select { |x| x.has_questions? }
  end
end
