require 'net/http'
require 'CGI'
class WelcomeController < ApplicationController

  # GET /welcome
  def index
    if session[:user_id].present?
        @user = User.find(session[:user_id])
        render 'dashboard'
    else
        render 'index'
    end
  end

  def oauth_redir
    # convert code to token
    if params[:code].present?
        result = JSON.parse(Net::HTTP.get(URI.parse("https://slack.com/api/oauth.access?client_id=#{RubyGettingStarted::Application.config.SLACK_CLIENT_ID}&client_secret=#{RubyGettingStarted::Application.config.SLACK_CLIENT_SECRET}&code=#{params[:code]}&redirect_uri=#{CGI.escape(request.base_url+'/welcome/oauth_redir')}")))

        client = Slack::Web::Client.new(token: result["access_token"])
        auth_test_data = client.auth_test
        user_id = auth_test_data["user_id"]
        team_id = auth_test_data["team_id"]
        team_name = auth_test_data["team_name"]
        user_info = client.users_info(user: user_id)

        # save team
        @team = Team.find_or_initialize_by(s_id: team_id, name: team_name)
        @team.save

        # save user
        @user = User.find_or_initialize_by(s_id: user_info["user"]["id"])
        @user.update(name: user_info["user"]["name"], s_id: user_info["user"]["id"], team_id: @team.id,token: result["access_token"], email: user_info["user"]["profile"]["email"], avatar: user_info["user"]["profile"]["image_original"])

        # save other users
        all_users = client.users_list["members"]
        all_users.each do |user|
            other_user = User.new(name: user["name"], s_id: user["id"], team_id: @team.id, email: user["profile"]["email"], avatar: user["profile"]["image_original"])
            other_user_does_not_already_exist = (User.find_by(s_id: user['id']).nil?)
            other_user_is_not_current_user = (user["id"] != @user.s_id)
            other_user.save if other_user_does_not_already_exist && other_user_is_not_current_user
        end

        # log user in
        reset_session
        session[:user_id] = @user.id

        # Load dashboard
        redirect_to '/'
    else
        render :text => "something went wrong authing you"
    end
  end

  def logout
    reset_session
    redirect_to '/'
  end

end
