class RespondentsController < ApplicationController
  layout "respondent"
  skip_before_action :authenticate_user!, only: %i[show signed_url]
  # Meant to be embedded on respondents' own sites (see public/widget.js), so it
  # can't keep the SAMEORIGIN default or every third-party iframe would be blocked.
  after_action -> { response.headers.delete("X-Frame-Options") }, only: :show

  def show
    @loop = Loop.find_by!(slug: params[:slug])
    return render :closed unless @loop.active? # checks if the loop is active before `show` renders show.html.erb
  end

  def signed_url
    @loop = Loop.find_by!(slug: params[:slug])
    # active? alone doesn't guarantee a provisioned agent (seeded/not-yet-activated
    # loops can be active with a nil agent_id). Never hand a blank id to ElevenLabs —
    # it 404s, which would surface as a 500. The front-end renders this gracefully.
    return head :not_found unless @loop.active? && @loop.agent_id.present?

    url = RestClient.get("https://api.elevenlabs.io/v1/convai/conversation/get-signed-url",
                         { params: { agent_id: @loop.agent_id }, "xi-api-key" => ENV.fetch("ELEVENLABS_API_KEY", nil) })
    render json: JSON.parse(url.body)
  end
end
