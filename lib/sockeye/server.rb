require 'json'
require 'eventmachine'
require 'websocket-eventmachine-server'

module Sockeye
  class Server

    attr_accessor :connections, :connection_map, :host, :port, :secret_token, :authentication_method

    def initialize(host:, port:, secret_token:, authentication_method: nil)
      self.connections = {}
      self.connection_map = {}
      self.host = host
      self.port = port
      self.secret_token = secret_token
      self.authentication_method = authentication_method
      puts "welcome"
    end

    # Safely parse data as JSON, but return nil values on failure
    #
    def json_try_parse(data)
      puts "json_try_parse"
      begin
        return JSON.parse(data, symbolize_names: true)
      rescue JSON::ParserError => e
        return nil
      end
    end

    # Call the supplied authentication method
    #
    def authenticate(token)
      puts "authenticating:"
      puts token
      authenticated = self.authentication_method.call(token)
      puts authenticated
      return authenticated
    end

    # Add a connection to the list and add a map entry to link the
    # connection object with an authenticated identifier
    #
    def add_connection(identifier:, connection:)
      puts "adding connection: "
      puts identifier
      connections[identifier] = [] if connections[identifier].nil?
      connections[identifier] << connection
      connection_map[connection.object_id] = identifier
    end

    # Safely remove the specified connection from the connections lists
    #
    def remove_connection(connection)
      identifier = connection_map[connection.object_id]
      puts "removing connection:"
      puts identifier
      if connections[identifier].is_a? Array
        connections[identifier].delete(connection)
        connections.delete(identifier) if connections[identifier].empty?
      end
      connection_map.delete(connection.object_id)
    end

    # Find all open connections associated with the specified identifiers
    # then attempt to push the payload to each of them
    #
    def deliver_to_many(payload:, identifiers:)
      puts "delivering payload:"
      puts payload.inspect
      puts "to identifiers:"
      puts identifiers.inspect
      identifiers.each do |identifier|
        puts "identifier:"
        puts identifier
        identified_connections = connections[identifier]
        puts "found #{identified_connections&.count.to_i} connections"
        next unless identified_connections.is_a? Array
        identified_connections.each do |connection|
          puts "connection:"
          puts connection.inspect
          begin
            puts "sending payload"
            connection.send({payload: payload, status: payload.dig(:status) || 200}.to_json, :type => :text)
            puts "sent"
          rescue
            puts "something blew up"
          end
        end
      end
    end

    # Main server connection listener loop. Uses an EventMachine and websocket
    # server to handle and abstract raw connections. Handles authentication
    # and delivery actions for clients and pushers.
    #
    def listen
      puts "listen..."
      EM.run do
        WebSocket::EventMachine::Server.start(host: self.host, port: self.port) do |ws|

          puts "listening"

          # Called when a new message arrives at the server
          #
          ws.onmessage do |message, type|
            puts "onmessage"

            # Attempt to parse the received data as JSON
            #
            message_json = json_try_parse(message)
            if message_json.nil?
              ws.send({payload: "invalid message", status: 400}.to_json, :type => :text)
              ws.close
            else

              # Execute the appropriate action based on JSON action
              #
              case message_json[:action].to_sym

              # Handle authentication requests by calling the authentication
              # method supplied on server setup
              #
              when :authenticate
                puts "authentication reuqest"
                authentication_result = authenticate(message_json[:payload])
                if authentication_result
                  add_connection(identifier: authentication_result, connection: ws)
                  ws.send({payload: "authenticated", status: 200}.to_json, :type => :text)
                else
                  ws.send({payload: "authentication failure", status: 401}.to_json, :type => :text)
                  ws.close
                end

              # Handle delivery requests by verifying the auth token supplied
              # then push out the payload to all connected specified clients
              #
              when :deliver
                puts "deliver"
                puts message_json
                if message_json[:secret_token] == self.secret_token
                  puts "good token"
                  deliver_to_many(payload: message_json[:payload], identifiers: [message_json[:identifiers]].flatten)
                  ws.send({payload: "payload pushed", status: 201}.to_json, :type => :text)
                  ws.close
                else
                  puts "delivery auth failure"
                  ws.send({payload: "authentication failure", status: 401}.to_json, :type => :text)
                  ws.close
                end

              else
                puts "invalid request"
                ws.send({payload: "invalid action", status: 405}.to_json, :type => :text)
                ws.close
              end

            end
          end

          # Cleanup connection lists when a connection is closed
          #
          ws.onclose do
            remove_connection(ws)
          end

        end
      end
    end
  end
end
