require 'spec_helper'

describe ResponsesController do
  let(:survey) { FactoryGirl.create(:survey_with_questions, :finalized => true, :organization_id => 1) }
  before(:each) do
    sign_in_as('cso_admin')
    session[:user_info][:org_id] = 1
  end

  context "POST 'create'" do
    let(:survey) { FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)}
    let(:question) { FactoryGirl.create(:question)}

    it "saves the response" do
      expect {
        post :create, :survey_id => survey.id

      }.to change { Response.count }.by(1)
    end

    it "saves the response to the right survey" do
      post :create, :survey_id => survey.id
      assigns(:response).survey.should ==  survey
    end

    it "saves the id of the user taking the response" do
      session[:user_id] = 1234
      post :create, :survey_id => survey.id
      Response.find_by_survey_id(survey.id).user_id.should == 1234
    end

    it "redirects to the edit path with a flash message" do
      post :create, :survey_id => survey.id
      response.should redirect_to edit_survey_response_path(:id => Response.find_by_survey_id(survey.id).id)
      flash[:notice].should_not be_nil
    end

    it "redirects to the root path with a flash message when the survey has expired" do
      survey.update_attribute(:expiry_date, 5.days.ago)
      post :create, :survey_id => survey.id
      response.should redirect_to surveys_path
      flash[:error].should_not be_nil
    end
  end

  context "GET 'index'" do
    before(:each) do
      session[:access_token] = "123"
      response = mock(OAuth2::Response)
      access_token = mock(OAuth2::AccessToken)
      names_response = mock(OAuth2::Response)
      organizations_response = mock(OAuth2::Response)
      controller.stub(:access_token).and_return(access_token)

      access_token.stub(:get).with('/api/users/names_for_ids', :params => {:user_ids => [1].to_json}).and_return(names_response)
      access_token.stub(:get).with('/api/organizations').and_return(organizations_response)
      names_response.stub(:parsed).and_return([{"id" => 1, "name" => "Bob"}, {"id" => 2, "name" => "John"}])
      organizations_response.stub(:parsed).and_return([{"id" => 1, "name" => "Foo"}, {"id" => 2, "name" => "Bar"}])
    end

    it "renders the list of responses for a survey if a cso admin is signed in" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 1)
      get :index, :survey_id => survey.id
      response.should be_ok
      assigns(:responses).should == Response.find_all_by_survey_id(survey.id)
    end

    it "sorts the responses by created_at, status" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res_1 = FactoryGirl.create(:response, :survey => survey, :status => "complete",
          :organization_id => 1, :user_id => 1, :created_at => Time.now)
      res_2 = FactoryGirl.create(:response, :survey => survey, :status => "incomplete",
          :organization_id => 1, :user_id => 1, :created_at => 10.minutes.ago)
      res_3 = FactoryGirl.create(:response, :survey => survey, :status => "complete",
          :organization_id => 1, :user_id => 1, :created_at => 10.minutes.ago)
      get :index, :survey_id => survey.id
      assigns(:responses).should == [res_1, res_3, res_2]
    end

    it "gets the user names for all the user_ids of the responses " do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 1)
      get :index, :survey_id => survey.id
      assigns(:user_names).should == {1 => "Bob", 2 => "John"}
    end

    it "gets the organization names for all the organization_ids of the responses " do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 1)
      get :index, :survey_id => survey.id
      assigns(:organization_names)[0].name.should == "Foo"
      assigns(:organization_names)[1].name.should == "Bar"
    end

    it "orders the complete responses by their `updated_at` time" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      responses = FactoryGirl.create_list(:response, 5, :survey => survey,
                                          :organization_id => 1, :user_id => 1, :status => 'complete')
      get :index, :survey_id => survey.id
      assigns(:complete_responses).should == responses
    end

    context "excel" do
      it "responds to XLSX" do
        survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
        resp = FactoryGirl.create(:response, :survey => survey, :status => 'complete')
        get :index, :survey_id => survey.id, :format => :xlsx
        response.should be_ok
      end

      it "assigns only the completed responses" do
        survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
        response = FactoryGirl.create(:response, :survey => survey, :status => 'complete')
        incomplete_response = FactoryGirl.create(:response, :status => 'incomplete', :survey => survey)
        validating_response = FactoryGirl.create(:response, :status => 'validating', :survey => survey)
        get :index, :survey_id => survey.id, :format => :xls
        assigns(:complete_responses).should == [response]
      end
    end
  end

  context "GET 'edit'" do
    it "renders the edit page" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2)
      get :edit, :id => res.id, :survey_id => survey.id
      response.should be_ok
      response.should render_template('edit')
    end

    it "assigns a survey and response" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2)
      get :edit, :id => res.id, :survey_id => survey.id
      assigns(:response).should == Response.find(res.id)
      assigns(:survey).should == survey
    end

    it "assigns public_response if the page is accessed externally using the public link" do
      session[:user_id] = nil
      survey = FactoryGirl.create(:survey, :finalized => true, :public => true)
      res = FactoryGirl.create(:response, :survey => survey, :session_token => "123")
      session[:session_token] = "123"
      get :edit, :id => res.id, :survey_id => survey.id, :auth_key => survey.auth_key
      response.should be_ok
      assigns(:public_response).should == true
    end
  end

  context "PUT 'update'" do
    it "doesn't run validations on answers that are empty" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      question_1 = FactoryGirl.create(:question, :survey => survey, :max_length => 15)
      question_2 = FactoryGirl.create(:question, :survey => survey, :mandatory => true)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2)
      answer_1 = FactoryGirl.create(:answer, :question => question_1, :response => res)
      answer_2 = FactoryGirl.create(:answer, :question => question_2, :response => res)
      res.answers << answer_1
      res.answers << answer_2

      put :update, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "", :id => answer_2.id},
                                   "1" => { :content => "hello", :id => answer_1.id} } }

        answer_1.reload.content.should == "hello"
      response.should redirect_to survey_responses_path
      flash[:notice].should_not be_nil
    end

    it "updates the response" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      question = FactoryGirl.create(:question, :survey => survey)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2)
      answer = FactoryGirl.create(:answer, :question => question)
      res.answers << answer

      put :update, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "yeah123", :id => answer.id} } }

      Answer.find(answer.id).content.should == "yeah123"
      response.should redirect_to survey_responses_path
      flash[:notice].should_not be_nil
    end

    it "renders edit page in case of any validations error" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      question = FactoryGirl.create(:question, :survey => survey, :mandatory => true)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2, :status => 'validating')
      answer = FactoryGirl.create(:answer, :question => question)
      res.answers << answer
      put :update, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "", :id => answer.id} } }

      response.should render_template('edit')
      answer.reload.content.should == "MyText"
      flash[:error].should_not be_empty
    end
  end

  context "PUT 'complete'" do
    let(:resp) { FactoryGirl.create(:response, :survey_id => survey.id, :organization_id => 1, :user_id => 1) }

    it "marks the response complete" do
      put :complete, :id => resp.id, :survey_id => resp.survey_id
      resp.reload.should be_complete
    end

    it "redirects to the response index page on success" do
      put :complete, :id => resp.id, :survey_id => resp.survey_id
      response.should redirect_to(survey_responses_path(resp.survey_id))
    end

    it "updates the response" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      question = FactoryGirl.create(:question, :survey => survey)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2)
      answer = FactoryGirl.create(:answer, :question => question)
      res.answers << answer

      put :complete, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "yeah123", :id => answer.id} } }

      Answer.find(answer.id).content.should == "yeah123"
      response.should redirect_to survey_responses_path
      flash[:notice].should_not be_nil
    end

    it "marks the response incomplete if save is unsuccessful" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      question = FactoryGirl.create(:question, :survey => survey, :mandatory => true)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2)
      answer = FactoryGirl.create(:answer, :question => question)
      res.answers << answer

      put :complete, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "", :id => answer.id} } }
      res.reload.should_not be_complete
    end

    it "doesn't mark an already complete response as incomplete when save if unsuccessful" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      question = FactoryGirl.create(:question, :survey => survey, :mandatory => true)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2, :status => 'complete')
      answer = FactoryGirl.create(:answer, :question => question)
      res.answers << answer
      put :complete, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "", :id => answer.id} } }
      res.reload.should be_complete
    end
  end

  context "DELETE 'destroy'" do
    let!(:survey) { FactoryGirl.create(:survey, :organization_id => 1, :finalized => true) }
    let!(:res) { FactoryGirl.create(:response, :survey => survey, :organization_id => 1, :user_id => 2) }

    it "deletes a survey" do
      expect { delete :destroy, :id => res.id, :survey_id => survey.id }.to change { Response.count }.by(-1)
      flash[:notice].should_not be_nil
    end

    it "redirects to the survey index page" do
      delete :destroy, :id => res.id, :survey_id => survey.id
      response.should redirect_to survey_responses_path
    end
  end
end
