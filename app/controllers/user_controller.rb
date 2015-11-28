class UserController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :require_user_id

  def require_user_id
    raise "Please pass in a user_id" if params[:user_id].blank?
    @user = User.find(params[:user_id])
    @client = Slack::Web::Client.new(token: @user.token)
  rescue Exception => e
    render json: {error: e.message}
  end

  def sync_messages
    message_count_before = Message.count(user_id: @user.id)

    dm_channels = @client.im_list["ims"]
    dm_channels.each do |dm_channel|
        channel = Channel.find_or_create_by!(s_id: dm_channel["id"], created: dm_channel["created"])
        sync_channel channel
    end

    message_count_after = Message.count(user_id: @user.id)
    render json: {success: "#{message_count_after - message_count_before} messages added"}

  end

  def message_count
    message_count = Message.where(user_id_from: @user.id).length + Message.where(user_id_to: @user.id).length
    render json: {message_count: message_count}
  end

  def details

    render json: {
      user: user_params(@user),
      total_to: Message.where(user_id_to: @user.id).length,
      total_from: Message.where(user_id_from: @user.id).length,
      top_teammates: get_top_teammates
    }
  end

  private

    # gets users ranked by how often they communicate with this user
    def get_top_teammates
      teammates = []
      nodes = User.where(team_id: @user.team_id)
      (0..nodes.length-1).to_a.each do |node_index|
        if nodes[node_index].id != @user.id 
          teammates.push({
            count: Message.where(user_id_to: @user.id, user_id_from: nodes[node_index].id).length + Message.where(user_id_to: nodes[node_index].id, user_id_from: @user.id).length,
            user: user_params(nodes[node_index])
          })
        end
      end
      teammates.sort_by! { |teammate| -teammate[:count] }
      return teammates
    end

    def user_params user
      user_hash = user.attributes
      user_hash.delete("token")
      user_hash.delete("created_at")
      user_hash.delete("updated_at")
      return user_hash
    end

    # Gets other user who is messaging on a channel given a list of messages
    def other_user messages
        other_user_sid = ((messages.map{|message| message["user"] }).uniq.compact - [@user.s_id])[0]
        User.find_by(s_id: other_user_sid)
    end

    def sync_channel channel
      has_more = true
      reached_existing_messages = false
      latest = nil

      # TODO: start counting messages starting on timestamp 1446084795, or oct 29, 2015
      min_timestamp = 1446084795

      message_data = @client.im_history(channel: channel["s_id"], latest: latest)
      other_user = other_user message_data["messages"]

      begin
          message_data = @client.im_history(channel: channel["s_id"], latest: latest)
          message_data["messages"].each do |message|
              if Message.exists?(channel: channel.id, ts: message["ts"])
                  reached_existing_messages = true
                  break
              else
                  if User.find_by(s_id: message["user"]).present? && other_user.present? && message["ts"].to_i > min_timestamp
                    from = User.find_by(s_id: message["user"]).id
                    to = (@user.id == from) ? other_user.id : @user.id
                    Message.new(user_id_from: from, user_id_to: to, channel_id: channel.id, s_type: message["type"], ts: message["ts"], text: message["text"]).save
                  end
              end
          end

          has_more = message_data["has_more"]
          latest = message_data["messages"].last["ts"] if has_more
      end while(has_more && !reached_existing_messages && latest.to_i > min_timestamp)
    end

end
