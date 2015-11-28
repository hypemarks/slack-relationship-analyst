class GraphController < ApplicationController

    before_action :require_team_id

    def require_team_id
        raise "Please pass in a team_id" if params[:team_id].blank?
        @team = Team.find(params[:team_id])
    rescue Exception => e
        render json: {error: e.message}
    end

    # return representation of graph
    def generate_graph
        nodes = User.where(team_id: @team.id)
        links = []

        (0..nodes.length-1).to_a.each do |index1|

            (0..nodes.length-1).to_a.each do |index2|

                if index1 != index2 
                    message_count = Message.where(user_id_from: nodes[index1].id, user_id_to: nodes[index2].id).length
                    link = {
                        source: index1,
                        target: index2,
                        value: message_count
                    }
                    links.push(link)
                end

            end

        end
        render json: {
            nodes: nodes,
            links: links
        }
    rescue Exception => e
        render json: {error: e.message}
    end

end