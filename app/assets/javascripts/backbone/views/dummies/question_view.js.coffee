SurveyBuilder.Views.Dummies ||= {}

# Represents a dummy question on the DOM
class SurveyBuilder.Views.Dummies.QuestionView extends Backbone.View

  initialize: (model, template) =>
    this.model = model
    this.template = template
    this.model.dummy_view = this
    this.model.on('change', this.render, this)
    this.model.on('change:errors', this.render, this)

  render: =>
    $(this.el).html('<div class="dummy_question_content"><div class="top_level_content"></div></div>') if $(this.el).is(':empty')
    this.model.set('content', I18n.t('js.untitled_question')) if _.isEmpty(this.model.get('content'))
    data = _.extend(this.model.toJSON().question, {errors: this.model.errors, image_url: this.model.get('image_url')})
    data = _(data).extend({question_number: this.model.question_number})
    $(this.el).children('.dummy_question_content').children(".top_level_content").html(Mustache.render(this.template, data))
    $(this.el).addClass("dummy_question")
    $(this.el).find('abbr').show() if this.model.get('mandatory')
    $(this.el).find('.star').raty({
      readOnly: true,
      number: this.model.get('max_length') || 5
    })

    $(this.el).children(".dummy_question_content").click (e) =>
      @show_actual(e)

    $(this.el).children('.dummy_question_content').children(".top_level_content").children(".delete_question").click (e) => @delete(e)

    return this

  delete: =>
    this.model.destroy()

  show_actual: (event) =>
    $(this.el).trigger("dummy_click")
    this.model.actual_view.show()
    $(this.el).children('.dummy_question_content').addClass("active")


  unfocus: =>
    $(this.el).children('.dummy_question_content').removeClass("active")
