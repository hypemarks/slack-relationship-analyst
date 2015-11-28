require 'rails_helper'
describe UserController do

    let(:team){
        team = Team.new(s_id: 'T02TAT0PR', name: 'TINT')
        team.save
        return team
    }
    let(:channel){
        im_list = JSON.parse(File.new('spec/fixtures/slack/im_list.json').read)
        channel = Channel.new(s_id: im_list['ims'][0]['id'], created: im_list['ims'][0]['created'])
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
        let!(:nik_user){
            nik_user = User.find_or_initialize_by(s_id: 'U02TAT0PT')
            nik_user.save
            return nik_user
        }
        let(:params){
            {
                user_id: user.id
            }
        }

        it "syncs 2 pages of messages" do
            subject
            expect(JSON.parse(response.body)).to eq({"success" => "114 messages added"})
            expect(Message.where(user_id_to: user.id).length).to eq(56)
            expect(Message.where(user_id_from: user.id).length).to eq(58)
            expect(Message.where(user_id_to: nik_user.id).length).to eq(58)
            expect(Message.where(user_id_from: nik_user.id).length).to eq(56)
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
                message = Message.new(user_id_to: user.id, channel_id: channel.id, ts: existing_timestamp, text: "existing message")
                message.save
                return message
            }
            it 'should only save up to the existing message' do
                subject
                expect(JSON.parse(response.body)).to eq({"success" => "#{nth_message_index} messages added"})
                expect( Message.where(user_id_to: user.id).length + Message.where(user_id_from: user.id).length ).to eq(nth_message_index+1)
            end
        end

    end

    describe '#message_count' do

        subject{ get :message_count, params }

        let(:params){
            {
                user_id: user.id
            }
        }

        let(:user){ create(:user, name: "user") }
        let!(:messages){ [
            create(:message, user_id_to: user.id),
            create(:message, user_id_to: user.id),
            create(:message, user_id_from: user.id)
        ] }

        let(:expected_response){
            {
                "message_count" => 3
            }
        }

        it 'returns the message count' do
            subject
            expect(JSON.parse(response.body)).to eq(expected_response)
        end

    end

    describe '#details' do
        subject{ get :details, params }

        let(:params){
            {
                user_id: user_1.id
            }
        }

        let(:user_1){ create(:user, name: "user_1") }
        let(:user_2){ create(:user, name: "user_2") }
        let(:user_3){ create(:user, name: "user_3") }
        let!(:messages){ [
            create(:message, user_id_to: user_1.id, user_id_from: user_2.id),
            create(:message, user_id_to: user_1.id, user_id_from: user_2.id),
            create(:message, user_id_to: user_2.id, user_id_from: user_1.id),
            create(:message, user_id_to: user_3.id, user_id_from: user_1.id)
        ] }

        def user_params user
          user_hash = user.attributes
          user_hash.delete("token")
          user_hash.delete("created_at")
          user_hash.delete("updated_at")
          return user_hash
        end

        let(:expected_response){
            {
                'user' => user_params(user_1),
                'total_to' => 2,
                'total_from' => 2,
                'top_teammates' => [
                    {   "count" => 3,
                        "user" => user_params(user_2)
                    },
                    {   "count" => 1,
                        "user" => user_params(user_3)
                    }
                ]
            }
        }

        it 'returns computed details on user' do
            subject
            expect(JSON.parse(response.body)).to eq(expected_response)
        end
    end

    after(:each) do
        user.destroy
    end

end