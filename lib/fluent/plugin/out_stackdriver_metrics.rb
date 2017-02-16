require 'stackdriver'
require 'fluent/plugin/output'

module Fluent
  class StackdriverMetricsOutput < BufferedOutput

    Fluent::Plugin.register_output('stackdriver_metrics', self)

    def initialize
      super
      require 'net/http'
      require 'uri'
    end

    config_param :api_key, :string
    config_param :instance_id, :string, :default => nil
    config_param :counter_maps, :array, :default => []
    config_param :metric_maps, :array, :default => []

    def configure(conf)
      @api_key = conf.delete('api_key')
      @instance_id = conf.delete('instance_id')
      @counter_maps = conf.['counter_maps']
      @metric_maps = conf.['metric_maps']

      @base_entry = {}
      @base_entry['instance'] = @instance_id if @instance_id

      super
    end

    def format(tag, time, record)
      # Everything goes into the buffer in a JSON format.
      { 'tag' => tag, 'time' => time, 'record' => record }.to_json + "\n"
    end

    def write(chunk)

      timestamp = Time.now.to_i
      data = []

      chunk.split("\n").each do |line|
        event = JSON.parse(line)

        incr_data = {}
        @increment_map.each do |cond_eval,name_eval|
          if eval(cond_eval)
            name = eval(name_val)
            incr_data['increment'][name] ||= 0
            incr_data['increment'][name] += 1
          end
        end

        incr_data.each do |k,v|
          data =+ [
            @base_entry.update({
              'name' => k,
              'value' => v,
              'collected_at' => timestamp
            })
          ]
        end

        @metric_map.each do |cond_eval,key_eval|
          if eval(cond_eval)
            kv = Hash.new(eval(kv_eval))
            kv.each do |k,v|
              data += [
                @base_entry.update({
                  'name' => k,
                  'value' => v
                  'collected_at' => event['time'].to_i
                })
              ]
            end
          end
        end

      end

      if data
        StackDriver.init @api_key
        StackDriver.send_multi_metric data
      end

    end

  end

end
