# Fluentd plugin to push metrics to the Stackdriver V1 (pre-Google) API

## Overview
This is a [buffered output plugin](http://docs.fluentd.org/v0.12/articles/buf_file) for fluentd.  Buffer chunks are parsed to generate metrics based on configured criteria which are then pushed to the Stackdriver V1 (pre-Google) API.  The metric publishing intervals are specified by the invervals for the buffer chunking.  The plugin can compute two different types of metrics: counts of log entries matching specified criteria, and metrics derived from log entries.  Currently, metric data collection has not really been tested, but count data collection is known to work.

Note that the plugin is incompatible with any plugin that uses the Ruby stackdriver library version >= 0.3.0.  The Stackdriver V1 API compatibility was dropped beginning with this version.

## Installation
```bash
gem install fluent-plugin-stackdriver-v1-metrics
```

## Configuration
```
<match>
  type stackdriver-v1_metrics
  api_key <Stackdriver V1 API key>
  instance_id <AWS instance ID that the metrics should be attached to (optioal)>
  counter_maps <JSON hash with the matching criteria and metric names>
  counter_defaults <JSON list of hashes to specify metric default values>
  metric_maps <JSON hash with ???>
  metric_defaults <JSON list of hashes to specify metric default values>
  [ fluent output buffer plugin configuration ]
</match>
```

`api_key`: Stackdriver V1 API key

`instance_id`: AWS instance ID that the metricsc should be attach to (optional)

`counter_maps`: JSON hash of event matching criteria and metric names

`counter_defaults`: JSON list of hashes with metric default values

`metric_maps`: JSON hash of event matching criteria and metric names

`metric_defaults`: JSON list of hashes with metric default values

## Methodology
The the metrics generation is performed by deserializing events from the buffer chunks to a hash called "event".  Two types of data creation can be specified -- counters and metrics.  For each type of data, there are two variables which can be set as JSON data structures in the configuration: "\*_maps" and "\*_defaults".

### Counter data
The counter_maps variable must be set to a JSON serialized hash (the plugin value will default to an empty hash if not specified).  Each key in the hash must be a valid Ruby command which evaluates to a Boolean.  The corresponding value must be a Ruby command which evaulates to a Stackdriver metric name (string).

While iterating through the events in the buffer chunk, the plugin will "eval" each key in the counter_maps hash and increment the metric with the name specified by the corresponding value.  For any key where no matching entry in the buffer chunk, there will be no metric created (not even a metric set to 0).  If a metric needs to be sent to Stackdriver even when there are no matching entries in the buffer chunk, then the metric names and default values must be set in the counter_defaults variable.

When used, the counter_defaults variable must be specified as a JSON serialized list of hashes.  In each hash in the array, the "name" key must be set to the Stackdriver metric name and the "value" key must be set to the value to use when there are no matching events for this metric in the buffer chunk.  The values will typically be 0, but any integer can be used.

### Metric data
The metric_maps variable must be set to a JSON serialized hash (the plugin value will default to an empty hash if not specified).  Each key in the hash must be a valid Ruby command which evaluates to a Boolean.  The corresponding value must be a Ruby command which evaulates to a Stackdriver metric name (string).

## Usage examples
The original use case which prompted the creation of this plugin was sending fluent error counts to Stackdriver.  This use case, in particular, does not lend itself to deriving metrics using the functionality of a logging backend since, when fleunt is throwing warnings or errors, the messages may not actually be getting to the logging backend.  Using this plugin allows for setting up metrics and alerting on fluent problems which does not depend upon successful log transmissions to the logging back end, at least.

```
<match *>
    type copy
    ...
    <store>
      type stackdriver-v1_metrics
      api_key <your Stackdriver V1 API key>
      instance_id <instance id to bind the metric to>
      counter_maps '{ "event[\"tag\"] =~ /^fluent\\.(warn|error)/": "\"fluentd.daemon.daemon.\".concat(event[\"tag\"] =~ /warn/ ? \"warnings\" : \"errors\")" }'
      counter_defaults '[ { "name": "fluentd.daemon.warnings", "value": 0 }, { "name": "fluentd.daemon.errors", "value": 0 } ]'
      buffer_type file
      buffer_path /var/lib/td-agent/buffer/stackdriver*
      disable_retry_limit true
      retry_wait 5s
      flush_interval 1m
      flush_at_shutdown true
    </store>
</match>
```
