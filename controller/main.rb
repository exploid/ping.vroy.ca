PingdomInstance = VRoy::Pingdom.new

class MainController < Ramaze::Controller
  layout '/layout'
  map '/'
  
  def index
    @average_response_time = PingdomInstance.average_response_time
    @uptime_percentage = "%.2f%" % PingdomInstance.uptime_percentage

    @outages = PingdomInstance.last_outages.map do |outage|
      format = TZInfo::Timezone.get('America/Halifax').strftime('at %r on %A, %B %e %Y (%Z)', outage[:from].utc)
      "Down for #{outage[:duration_in_minutes]} minute(s) starting #{format}"
    end[0..10]
  end

end
