require 'rails_helper'
describe UserController do

    let(:team){
        team = Team.new(s_id: 'T02TAT0PR', name: 'TINT')
        team.save
        return team
    }
    let(:channel){
        im_list = JSON.parse(File.new('spec/fixtures/slack/im_list.json').read)
        channel = Channel.new(s_id: im_list['ims'][0]['id'], user_id: user.id, created: im_list['ims'][0]['created'])
        channel.save
        return channel
    }
    let(:token){ 'xoxp-2928918807-2929677141-4717070003-ce5e13' }
    let(:user){
        user = User.new(name: 'ryo', s_id: 'U02TBKX45', team_id: team.id, token: token)
        user.save
        return user
    }

    before(:each) do
        im_list = File.new 'spec/fixtures/slack/im_list.json'

        # 2 pages of chat history between Nik and Ryo
        # 1st page is 100 messages, and has_more:true
        # 2nd page is 14 messages, and has_more:false

        im_history_1 = File.new 'spec/fixtures/slack/im_history_nik_1.json'
        im_history_2 = File.new 'spec/fixtures/slack/im_history_nik_2.json'
        stub_request(:post, "https://slack.com/api/im.list").to_return(body: im_list)
        stub_request(:post, "https://slack.com/api/im.history").
            with( body: hash_including({latest: nil}) ).
            to_return(body: im_history_1)
        stub_request(:post, "https://slack.com/api/im.history").
            with( body: hash_including({latest: '1446246684.000003'}) ).
            to_return(body: im_history_2)
    end

    describe '#sync_messages' do

        subject{ get :sync_messages, params }

        let(:params){
            {
                user_id: user.id
            }
        }

        it "syncs 2 pages of messages" do
            subject
            expect(JSON.parse(response.body)).to eq({"success" => "114 messages added"})
            expect(Message.count(user_id: user.id)).to eq(114)
        end

        context 'when user_id is not passed in' do
            let(:params){nil}
            it 'returns an error' do
                subject
                expect(JSON.parse(response.body)).to eq({"error" => "Please pass in a user_id"})
            end
        end

        context 'when there is a message already in the database' do
            let(:nth_message_index){ 4 }
            let(:existing_timestamp){
                # grab the 5th posts timestamp
                im_history = JSON.parse(File.new('spec/fixtures/slack/im_history_nik_1.json').read)
                im_history['messages'][nth_message_index]['ts']
            }
            let!(:existing_message){
                message = Message.new(user_id: user.id, channel_id: channel.id, ts: existing_timestamp, text: "existing message")
                message.save
                return message
            }
            it 'should only save up to the existing message' do
                subject
                expect(JSON.parse(response.body)).to eq({"success" => "#{nth_message_index} messages added"})
                expect(Message.count(user_id: user.id)).to eq(nth_message_index+1)
            end
        end

    end

    after(:each) do
        user.destroy
    end

end