module Fluent
  class GraphiteMetricsOutput < BufferedOutput

    Plugin.register_output('graphite_metrics', self)

    def initialize
      super
      require 'graphite-api'
    end

    config_param :graphite_uri, :string, :default => 'tcp://localhost:2003'
    config_param :prefix, :string, :default => nil
    config_param :instance_id, :string, :default => nil
    config_param :counter_maps, :hash, :default => {}
    config_param :counter_defaults, :array, :default => []
    config_param :metric_maps, :hash, :default => {}
    config_param :metric_defaults, :array, :default => []

    def configure(conf)
      super(conf) {
        @graphite_uri = conf.delete('graphite_uri')
        @prefix = conf.delete('prefix')
        @instance_id = conf.delete('instance_id')
        @counter_maps = conf.delete('counter_maps')
        @counter_defaults = conf.delete('counter_defaults')
        @metric_maps = conf.delete('metric_maps')
        @metric_defaults = conf.delete('metric_defaults')
      }

      @base_entry = {}
      @base_entry['prefix'] = @prefix if @prefix

    end

    def format(tag, time, record)
      # Everything goes into the buffer in a JSON format.
      { 'tag' => tag, 'time' => time, 'record' => record }.to_json + "\n"
    end

    def write(chunk)

      timestamp = Time.now.to_i
      data = []

      count_data = {}
      metric_data = {}

      chunk.read.chomp.split("\n").each do |line|
        event = JSON.parse(line)

        @counter_maps.each do |k,v|
          if eval(k)
            name = eval(v) 
            count_data[name] ||= 0
            count_data[name] += 1
          end
        end

        @metric_maps.each do |k,v|
          if eval(k)
            if eval(v)
              data << @base_entry.merge({ 'collected_at' => event['time'].to_i }).merge(eval(v))
            end
          end
        end

      end

      count_data.each do |name,value|
        data << @base_entry.merge({
          'name' => name,
          'value' => value,
          'collected_at' => timestamp
        })
      end

      @counter_defaults.each do |e|
        if not count_data.key?(e['name'])
          data << @base_entry.merge({'collected_at' => timestamp}).merge(e)
        end
      end

      @metric_defaults.each do |e|
        if not metric_data.key?(e['name'])
          data << @base_entry.merge({'collected_at' => timestamp}).merge(e)
        end
      end

      if data
        stackdriver_to_graphite(data).each do |t,metrics|
          post(metrics,t)
        end
      end

    end

  end

  def stackdriver_to_graphite(metrics)
    # Convert the Stackdriver API format to Graphite format so that the
    # datastructure and parser don't have to be completely refactored.

    data = {}

    metrics.each do |elem|
      if not data.key?(elem['collected_at'])
        data[elem['collected_at']] = {}
      end
      data[elem['collected_at']][elem['name']] = elem['value']
    end

    done

    yield data

  end

  def post(metrics, time)
    trial ||= 1
    @client.metrics(metrics, time)
  rescue Errno::ETIMEDOUT
    # after long periods with nothing emitted, the connection will be closed and result in timeout
    if trial <= @max_retries
      log.warn "out_graphite_metrics: connection timeout to #{@host}:#{@port}. Reconnecting... "
      trial += 1
      connect_client!
      retry
    else
      log.error "out_graphite_metrics: ERROR: connection timeout to #{@host}:#{@port}. Exceeded max_retries #{@max_retries}"
    end
  rescue Errno::ECONNREFUSED
    log.warn "out_graphite_metrics: connection refused by #{@host}:#{@port}"
  rescue SocketError => se
    log.warn "out_graphite_metrics: socket error by #{@host}:#{@port} :#{se}"
  rescue StandardError => e
    log.error "out_graphite_metrics: ERROR: #{e}"
  end
  
  def connect_client!
    @client = GraphiteAPI.new(graphite: "#{@host}:#{@port}")
  end

end
