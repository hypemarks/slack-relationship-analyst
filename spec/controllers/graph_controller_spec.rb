require 'rails_helper'
describe GraphController do

    let(:team){ create(:team) }
    let(:channel){ create(:channel) }
    let(:user_1){ create(:user, name: "user1", team_id: team.id) }
    let(:user_2){ create(:user, name: "user2", team_id: team.id) }
    let!(:messages){ [
        create(:message, user_id_to: user_1.id, user_id_from: user_2.id, channel_id: channel.id),
        create(:message, user_id_to: user_1.id, user_id_from: user_2.id, channel_id: channel.id),
        create(:message, user_id_to: user_2.id, user_id_from: user_1.id, channel_id: channel.id)
    ] }

    describe '#generate_graph' do

        subject{ get :generate_graph, params }

        context 'when team_id is not passed in' do
            let(:params){ nil }
            it 'returns an error' do
                subject
                expect(JSON.parse(response.body)).to eq({"error" => "Please pass in a team_id"})
            end
        end

        context 'when valid team_id is passed in' do
            let(:params){ {
                team_id: team.id
            } }
            let(:expected_links){
                [
                    {
                        "source"=>0,
                        "target"=>1,
                        "value"=>1
                    },
                    {
                        "source"=>1,
                        "target"=>0,
                        "value"=>2
                    }
                ]
            }
            it 'returns graph data' do
                subject
                res = JSON.parse(response.body)
                expect(res["nodes"][0]["id"]).to eq(user_1.id)
                expect(res["nodes"][1]["id"]).to eq(user_2.id)
                expect(res["links"]).to eq(expected_links)
            end
        end

    end

end