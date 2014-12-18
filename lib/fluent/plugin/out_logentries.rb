require 'socket'
require 'openssl'

class LogentriesOutput < Fluent::BufferedOutput
  class ConnectionFailure < StandardError; end
  # First, register the plugin. NAME is the name of this plugin
  # and identifies the plugin in the configuration file.
  Fluent::Plugin.register_output('logentries', self)

  config_param :token, :string

  def configure(conf)
    super
  end

  def start
    super
  end

  def shutdown
    super
  end

  def client
    context = OpenSSL::SSL::SSLContext.new
    socket = TCPSocket.new "api.logentries.com", 20000
    ssl_client = OpenSSL::SSL::SSLSocket.new socket, context
    @_socket = ssl_client.connect
  end

  # This method is called when an event reaches to Fluentd.
  def format(tag, time, record)
    return [tag, record].to_msgpack
  end

  # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
  def write(chunk)
    chunk.msgpack_each do |tag, record|
      next unless record.is_a? Hash
      send_logentries(@token + ' ' + Yajl.dump(record))
    end
  end

  def send_logentries(data)
    retries = 0
    begin
      client.puts data
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
      if retries < 2
        retries += 1
        @_socket = nil
        log.warn "Could not push logs to Logentries, resetting connection and trying again. #{e.message}"
        sleep 2**retries
        retry
      end
      raise ConnectionFailure, "Could not push logs to Logentries after #{retries} retries. #{e.message}"
    end
  end

end
