require "time"

module VRoy
  
  # Simple caching class around hash key/value pairs
  class Cache < Hash
    
    # Receives a optional time_limit on the objects in the cache
    def initialize(time_limit=60)
      @time_limit = time_limit
    end

    # When reading the value, return nil if the @time_limit as expired in the timestamp
    def [](key)
      time_updated, value = super

      if (Time.now.to_i - time_updated.to_i).to_i > @time_limit.to_i
        self[key] = nil
        return nil
      else
        return value
      end
    end

    # Wrap the value in an array along with a timestamp
    def []=(key, value)
      value = [ Time.now, value ]
      super
    end
  end

end
