##= require ./question_factory
# Collection of dummy questions
class SurveyBuilder.Views.DummyPaneView extends Backbone.View
  el: "#dummy_pane"

  initialize: (survey_model) =>
    @questions = []
    @survey_model = survey_model
    @add_survey_details(survey_model)
    ($(this.el).find("#dummy_questions")).sortable({
      update : ((event, ui) =>
        window.loading_overlay.show_overlay("Reordering Questions")
        _.delay(=>
          this.reorder_questions(event,ui)
        , 10)
      )
    })

  add_question: (type, model, parent) =>
    view = SurveyBuilder.Views.QuestionFactory.dummy_view_for(type, model)
    @questions.push(view)
    model.on('destroy', this.delete_question_view, this)
    $(this.el).children("#dummy_questions").append(view.render().el)

  add_category: (model) =>
    view = new SurveyBuilder.Views.Dummies.CategoryView(model)
    @questions.push(view)
    model.on('destroy', this.delete_question_view, this)
    $(this.el).children("#dummy_questions").append(view.render().el)

  insert_view_at_index: (view, index) =>
    if index == -1
      @questions.push(view)
    else
      @questions.splice(index + 1, 0, view)

  add_survey_details: (survey_model) =>
    template = $("#dummy_survey_details_template").html()
    @dummy_survey_details = new SurveyBuilder.Views.Dummies.SurveyDetailsView({ model: survey_model, template: template})
    @show_survey_details()

  render: =>
    ($(this.el).find("#dummy_survey_details").append(@dummy_survey_details.render().el))
    ($(this.el).find("#dummy_questions").append(question.render().el)) for question in @questions
    return this

  unfocus_all: =>
    $(@dummy_survey_details.el).removeClass("active")
    question.unfocus() for question in @questions

  delete_question_view: (model) =>
    question = _(@questions).find((question) => question.model == model )
    question.remove()
    @questions = _(@questions).without(question)
    @reorder_questions_after_deletion()
    @render()

  reorder_questions: (event, ui) =>
    @reorder_questions_after_deletion(false)
    @sort_questions_by_order_number()
    @hide_overlay(event)

  hide_overlay: (event) =>
      window.loading_overlay.hide_overlay() if event

  sort_questions_by_order_number: =>
    @questions = _(@questions).sortBy (question) =>
      question.model.get('order_number')
    @render()

  reorder_questions_after_deletion: (is_deleting=true) =>
    last_order_number = @survey_model.next_order_number()
    _(@questions).each (question) =>
        index = $(question.el).index()
        question.model.set({order_number: last_order_number + index + 1}, {silent: is_deleting})
        question.model.question_number = index + 1

        question.reorder_question_number() if question instanceof SurveyBuilder.Views.Dummies.QuestionWithOptionsView
        question.reorder_question_number() if question instanceof SurveyBuilder.Views.Dummies.CategoryView

  show_survey_details: =>
    @dummy_survey_details.show_actual()

