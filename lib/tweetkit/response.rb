require 'json'
require 'pry'

module Tweetkit
  module Response
    class Tweets
      include Enumerable

      attr_accessor :connection, :meta, :options, :original_response, :resources, :response, :tweets, :twitter_request

      def initialize(response, **options)
        parse! response, **options
      end

      def parse!(response, **options)
        parse_response response
        extract_and_save_tweets
        extract_and_save_meta
        extract_and_save_resources
        extract_and_save_options(**options)
        extract_and_save_request
      end

      def parse_response(response)
        @original_response = response.body
        @response = JSON.parse(@original_response)
      end

      def extract_and_save_tweets
        if @response['data']
          @tweets = @response['data'].collect { |tweet| Tweetkit::Response::Tweets::Tweet.new(tweet) }
        else
          @tweets = []
        end
      end

      def extract_and_save_meta
        @meta = Tweetkit::Response::Tweets::Meta.new(@response['meta'])
      end

      def extract_and_save_resources
        @resources = @response['includes']
      end

      def extract_and_save_options(**options)
        @options = options
      end

      def extract_and_save_request
        @connection = @options[:connection]
        @twitter_request = @options[:twitter_request]
      end

      def each(*args, &block)
        tweets.each(*args, &block)
      end

      def last
        tweets.last
      end

      def next_page
        connection.params.merge!({ next_token: meta.next_token })
        response = connection.get(twitter_request[:previous_url])
        parse! response,
               connection: connection,
               twitter_request: {
                 previous_url: twitter_request[:previous_url],
                 previous_query: twitter_request[:previous_query]
               }
        self
      end

      def prev_page
        connection.params.merge!({ previous: meta.previous_token })
        response = connection.get(twitter_request[:previous_url])
        parse! response,
               connection: connection,
               twitter_request: {
                 previous_url: twitter_request[:previous_url],
                 previous_query: twitter_request[:previous_query]
               }
        self
      end

      # def method_missing(method, **args)
      #   tweets.public_send(method, **args)
      # end

      # def respond_to_missing?(method, *args)
      #   tweets.respond_to?(method)
      # end

      class Tweet
        attr_accessor :data

        def initialize(tweet)
          @data = tweet
        end

        def id
          data['id']
        end

        def text
          data['text']
        end

        # def method_missing(attribute)
        #   data = tweet[attribute.to_s]
        #   data.empty? ? super : data
        # end

        # def respond_to_missing?(method, *args)
        #   tweet.respond_to?(method) || super
        # end
      end

      class Resources
        include Enumerable

        VALID_RESOURCES = Set['users', 'tweets', 'media']

        attr_accessor :resources

        def initialize(resources)
          @resources = resources
          build_and_normalize_resources(resources) unless resources.nil?
        end

        def build_and_normalize_resources(resources)
          resources.each_key do |resource_type|
            normalized_resource = build_and_normalize_resource(@resources[resource_type], resource_type)
            instance_variable_set(:"@#{resource_type}", normalized_resource)
            self.class.define_method(resource_type) { instance_variable_get("@#{resource_type}") }
          end
        end

        def build_and_normalize_resource(resource, resource_type)
          Tweetkit::Response::Resources::Resource.new(resource, resource_type)
        end

        def method_missing(method, **args)
          return nil if VALID_RESOURCES.include?(method.to_s)

          super
        end

        def respond_to_missing?(method, *args)
          VALID_RESOURCES.include?(method.to_s) || super
        end

        class Resource
          include Enumerable

          attr_accessor :normalized_resource, :original_resource

          RESOURCE_NORMALIZATION_KEY = {
            'users': 'id'
          }.freeze

          def initialize(resource, resource_type)
            @original_resource = resource
            @normalized_resource = {}
            normalization_key = RESOURCE_NORMALIZATION_KEY[resource_type.to_sym]
            resource.each do |data|
              key = data[normalization_key]
              @normalized_resource[key.to_i] = data
            end
          end

          def each(*args, &block)
            @normalized_resource.each(*args, &block)
          end

          def each_data(*args, &block)
            @normalized_resource.values.each(*args, &block)
          end

          def find(key)
            @normalized_resource[key.to_i]
          end
        end
      end

      class Meta
        attr_accessor :data

        def initialize(meta)
          @data = meta
        end

        def next_token
          @data['next_token']
        end

        def previous_token
          @data['previous_token']
        end

        # def method_missing(attribute, **args)
        #   data = meta[attribute.to_s]
        #   data.empty? ? super : data
        # end

        # def respond_to_missing?(method, *args)
        #   meta.respond_to? method
        # end
      end
    end
  end
end
