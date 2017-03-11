# require "sockeye/server/version"

require 'json'
require 'eventmachine'
require 'websocket-eventmachine-server'

module Sockeye
  class Server

    attr_accessor :connections, :host, :port, :secret_token, :authentication_method

    def initialize(host:, port:, secret_token:, authentication_method: nil)
      self.host = host
      self.port = port
      self.secret_token = secret_token
      self.authentication_method = authentication_method
    end

    def listen

      EM.run do
        WebSocket::EventMachine::Server.start(host: self.host, port: self.port) do |ws|

          ws.onopen do
            puts "Client connected"
          end

          ws.onmessage do |message, type|

            # Attempt to parse the received data as JSON
            #
            message_json = json_try_parse(message)
            if message_json.nil?
              puts "Invalid message"
              ws.send({payload: "invalid message", status: 400}.to_json, :type => :text)
              ws.close
            else

              puts "message:"
              puts message_json.inspect

              # Execute the appropriate action based on JSON action
              #
              case message_json[:action].to_sym
              when :authenticate
                puts "authenticate action"
                authentication_result = authenticate(message_json[:token])
                if authentication_result
                  puts "================="
                  puts self.inspect
                  puts ws.inspect
                  puts "================="
                  ws.send({payload: "authenticated", status: 200}.to_json, :type => :text)
                else
                  puts "Authentication failure"
                  ws.send({payload: "authentication failure", status: 401}.to_json, :type => :text)
                  ws.close
                end


              when :deliver
                puts "deliver action"
                if message_json[:secret_token] == self.secret_token
                  puts "secret token verified"
                  puts "broadcasting..."
                  ws.send({payload: "payload pushed", status: 201}.to_json, :type => :text)
                  ws.close
                else
                  puts "Authentication failure"
                  ws.send({payload: "authentication failure", status: 401}.to_json, :type => :text)
                  ws.close
                end

              else
                puts "invalid action"
                ws.send({payload: "invalid action", status: 405}.to_json, :type => :text)
                ws.close
              end

            end
          end

          ws.onclose do
            puts "Client disconnected"
          end
        end
      end

    end

    def json_try_parse(data)
      begin
        return JSON.parse(data, symbolize_names: true)
      rescue JSON::ParserError => e
        return nil
      end
    end

    def authenticate(token)
      puts "authenticating"
      result = self.authentication_method.call(token)
      puts "done authentication. Result:"
      puts result.inspect
      return result
    end

  end
end
