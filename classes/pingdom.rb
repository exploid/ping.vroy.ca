require "net/http"
require "net/https"
require "json"
require "yaml"
require "tzinfo"

module VRoy
  
  # Small abstraction of the Pingdom API to pull a few numbers
  class Pingdom

    # opts = {
    #   reset_interval - the interval between cache resets
    #   config - filename of the config, default=config.yml
    def initialize(opts={})
      opts = {
        :reset_interval => 300,
        :config => "pingdom.yml"
      }.merge!(opts)
      
      config = YAML.load_file( opts[:config] )

      @api_key = config["api_key"]
      @username = config["username"]
      @password = config["password"]

      @cache = Cache.new( opts[:reset_interval] )
    end

    # Gets the pingdom checkid from the API and caches it. I only have one check
    # at the moment so simply getting the id of the first check.
    #
    # Returns the checkid of my account
    def checkid
      @checkid ||= make_pingdom_request("/api/2.0/checks")["checks"].first["id"]
      return @checkid
    end

    # Get an array of hashes representing the outages
    # 
    #   {
    #     :from => Time,
    #     :to => Time,
    #     :duration_in_minutes
    #   }
    def last_outages
      if !@cache[:outages]
        outages = []

        # Since we cache the outages, get all of the outages (from=0)
        make_pingdom_request("/api/2.0/summary.outage/#{checkid}?order=desc&from=0")["summary"]["states"].each do |state|
          if state["status"] == "down"
            from = Time.at( state["timefrom"] )
            to = Time.at( state["timeto"] )

            outages << {
              :from => from,
              :to => to,
              :duration_in_minutes => (to-from).to_i/60
            }
          end
        end
        
        @cache[:outages] = outages
      end

      return @cache[:outages]
    end
    
    # Returns {
    #   :average_response_time => <Fixnum: milliseconds>,
    #   :uptime_percentage => <Float: uptime_percentage>
    # }
    def summary_average
      if !@cache[:summary_average]
        averages = make_pingdom_request("/api/2.0/summary.average/#{checkid}?includeuptime=true")

        average_response_time = averages["summary"]["responsetime"]["avgresponse"].to_i

        uptime = averages["summary"]["status"]["totalup"].to_f
        downtime = averages["summary"]["status"]["totaldown"].to_f
        uptime_percentage = (uptime/(uptime+downtime)*100)
        
        @cache[:summary_average] = {
          :average_response_time => average_response_time,
          :uptime_percentage => uptime_percentage
        }
      end
      return @cache[:summary_average]
    end

    # Wrap the #summary_average method to get the average_response_time
    def average_response_time
      return summary_average[:average_response_time]
    end
    
    # Wrap the #summary_average method to get the uptime_percentage
    def uptime_percentage
      return summary_average[:uptime_percentage]
    end

    private

    def make_pingdom_request(path, mod=Net::HTTP::Get)
      http = Net::HTTP.new("api.pingdom.com", 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      req = mod.new(path, 'App-Key' => @api_key)
      req.basic_auth(@username, @password)

      return JSON.parse( http.request(req).body )
    end

  end
end
