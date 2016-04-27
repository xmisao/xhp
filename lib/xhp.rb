require 'net/http'
require 'json'

module XHP
  CLIENT_ID = '346.iMG9jv2hBk.apps.healthplanet.jp'
  CLIENT_SECRET = '1460033240967-qQ94jRSpvPlnlwNEGTVQ61hDwvmAdSvL0JVoJ40W'

  module HTTP
    def post(url)
      uri = URI.parse(url)
      request = Net::HTTP::Post.new(uri.request_uri)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      http.set_debug_output $stderr if $xhp_debug

      http.start do |h|
        response = h.request(request)
      end
    end

    def get(url)
      uri = URI.parse(url)
      request = Net::HTTP::Get.new(uri.request_uri)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      http.set_debug_output $stderr if $xhp_debug

      http.start do |h|
        response = h.request(request)
      end
    end
  end

  module HealthPlanet
    module OAuth
      include XHP::HTTP

      class Scope
        def initialize(innerscan = true, sphygmomanometer = true, pedometer = true, smug = true)
          @innerscan, @sphygmomanometer, @pedometer, @smug = innerscan, sphygmomanometer, pedometer, smug
        end

        def to_s
          a = []
          a << 'innerscan' if @innerscan
          a << 'sphygmomanometer' if @sphygmomanometer
          a << 'pedometer' if @pedometer
          a << 'smug' if @smug
          a.join(',')
        end
      end

      class RequestToken
        attr_reader :access_token, :expires_in, :refresh_token

        def initialize(access_token, expires_in, refresh_token)
          @access_token, @expires_in, @refresh_token = access_token, expires_in, refresh_token
        end
      end

      def get_auth_url(redirect_uri = 'https://www.healthplanet.jp/success.html',
                       scope = Scope.new,
                       response_type = 'code')
        "https://www.healthplanet.jp/oauth/auth?client_id=#{CLIENT_ID}&redirect_uri=#{redirect_uri}&scope=#{scope.to_s}&response_type=#{response_type}"
      end

      def token(code,
                redirect_uri = 'https://www.healthplanet.jp/success.html',
                grant_type = 'authorization_code')
        url = "https://www.healthplanet.jp/oauth/token.?client_id=#{CLIENT_ID}&client_secret=#{CLIENT_SECRET}&redirect_uri=#{redirect_uri}&code=#{code}&grant_type=#{grant_type}"
        res = post(url)
        raise "OAuth Token API return response code #{res.code}" unless res.code == '200'
        json = JSON.parse(res.body)
        RequestToken.new(json['access_token'], json['expires_in'], json['refresh_token'])
      end
    end

    module Status
      class Tag
        def to_s
          '6021,6022,6023,6024,6025,6026,6027,6028,6029'
        end
      end

      def innerscan(token, tag = nil, date = 1, from = nil, to = nil)
        url_part = ["https://www.healthplanet.jp/status/innerscan.json?access_token=#{token.access_token}&date=#{date}"]
        url_part << "tag=#{tag.to_s}" if tag
        url_part << "from=#{format_date(from)}" if from
        url_part << "to=#{format_date(to)}" if to

        url = url_part.join('&')
        res = get(url)
        raise "Status API return response code #{res.code}" unless res.code == '200'
        json = JSON.parse(res.body)
        json.extend(ResponseHolder)
        json.http_response = res
        json
      end

      def format_date(date)
        if date.kind_of?(Date)
          date.strftime("%Y%m%d%H%M%s")
        elsif date.kind_of?(String)
          date
        end
      end
    end
  end

  module ResponseHolder
    attr_accessor :http_response
  end

  class Client
    include HealthPlanet::OAuth
    include HealthPlanet::Status
  end
end
