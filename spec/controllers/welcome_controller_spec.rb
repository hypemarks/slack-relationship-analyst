require 'rails_helper'
describe WelcomeController do

    before(:each) do
        auth_test = File.new 'spec/fixtures/slack/auth_test.json'
        stub_request(:any, /slack.com\/api\/auth\.test/).
            to_return(body: auth_test)

        users_info = File.new 'spec/fixtures/slack/users_info.json'
        stub_request(:any, /slack.com\/api\/users\.info/).
            to_return(body: users_info)

        users_list = File.new 'spec/fixtures/slack/users_list.json'
        stub_request(:any, /slack.com\/api\/users\.list/).
            to_return(body: users_list)

        oauth_response = File.new 'spec/fixtures/slack/oauth_access.json'
        stub_request(:any, /slack.com\/api\/oauth\.access/).
            to_return(body: oauth_response)
    end

    describe '#oauth_redir' do

        let(:params){
            {
                code: "oauth code"
            }
        }
        subject{ get :oauth_redir, params }

        RSpec.shared_examples "an oauth_redir" do
            it 'creates a session' do
                subject
                s_id = JSON.parse(File.new('spec/fixtures/slack/auth_test.json').read)["user_id"]
                user = User.find_by(s_id: s_id)
                expect(session[:user_id]).to eq(user.id)
            end
            it 'creates a team' do
                subject
                team_s_id = JSON.parse(File.new('spec/fixtures/slack/auth_test.json').read)["team_id"]
                expect(Team.count(s_id: team_s_id)).to eq(1)
            end
            it 'creates 2 users' do
                subject 
                team_s_id = JSON.parse(File.new('spec/fixtures/slack/auth_test.json').read)["team_id"]
                team = Team.find_by(s_id: team_s_id)
                expect(User.count(team_id: team.id)).to eq(2)
            end
            it 'saves the token on the current user' do
                subject
                s_id = JSON.parse(File.new('spec/fixtures/slack/auth_test.json').read)["user_id"]
                user = User.find_by(s_id: s_id)
                token = JSON.parse(File.new('spec/fixtures/slack/oauth_access.json').read)["access_token"]
                expect(user.token).to eq(token)
            end
        end

        context 'when user does not already exist' do
            it_behaves_like "an oauth_redir"
        end

        context 'when user already exists, but has no token' do
            let!(:existing_user){
                auth_test = JSON.parse(File.new('spec/fixtures/slack/auth_test.json').read)
                user = User.new(name: auth_test["user"], s_id: auth_test["user_id"])
                user.save
                return user
            }
            it_behaves_like "an oauth_redir"
        end

    end

end