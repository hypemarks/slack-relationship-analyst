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
        channel = Channel.find_or_create_by!(s_id: dm_channel["id"], user_id: @user.id, created: dm_channel["created"])
        sync_channel channel
    end

    message_count_after = Message.count(user_id: @user.id)
    render json: {success: "#{message_count_after - message_count_before} messages added"}

  end

  def sync_channel channel
    has_more = true
    reached_existing_messages = false
    latest = nil
    begin
        message_data = @client.im_history(channel: channel["s_id"], latest: latest)
        message_data["messages"].each do |message|
            if Message.exists?(channel: channel.id, ts: message["ts"])
                reached_existing_messages = true
                break
            else
                Message.new(user_id: @user.id, channel_id: channel.id, s_type: message["type"], ts: message["ts"], text: message["text"]).save
            end
        end

        has_more = message_data["has_more"]
        latest = message_data["messages"].last["ts"] if has_more
    end while(has_more && !reached_existing_messages)
  end

end
