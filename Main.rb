require 'net/http'
require 'uri'
require 'timeout'
require 'json'

class LicenseKeyFetcher
  FETCH_TIMEOUT = 5
  MAX_RETRIES = 3
  API_ENDPOINT = URI::HTTPS.build(host: 'backend.reksfn.dev', path: '/ext/get-code')

  def fetch_license_key
    retries = 0
    begin
      response = make_request(API_ENDPOINT)
      handle_response(response)
    rescue StandardError => e
      retries += 1
      if retries < MAX_RETRIES
        puts "リトライ #{retries}回目。 エラー: #{e.message}"
        retry
      else
        puts "最大リトライ回数を超えました。 エラー: #{e.message}"
      end
    end
  end

  private

  def make_request(url)
    request = Net::HTTP::Get.new(url)
    request["User-Agent"] = generate_user_agent()

    req_options = {
      use_ssl: url.scheme == 'https',
    }

    log_request(request)

    Timeout.timeout(FETCH_TIMEOUT) do
      Net::HTTP.start(url.hostname, url.port, req_options) do |http|
        http.request(request)
      end
    end
  rescue Timeout::Error
    puts "タイムアウトエラー: リクエストがタイムアウトしました"
  rescue Errno::ECONNREFUSED
    puts "接続エラー: 接続が拒否されました"
  rescue Errno::EHOSTUNREACH
    puts "接続エラー: ホストに到達できませんでした"
  rescue Errno::ENETUNREACH
    puts "接続エラー: ネットワークに到達できませんでした"
  rescue SocketError => e
    puts "ソケットエラー: #{e.message}"
  end

  def handle_response(response)
    log_response(response)

    case response
    when Net::HTTPSuccess
      puts "ライセンスキーは: #{response.body}"
    when Net::HTTPRedirection
      puts "リダイレクトエラー: #{response['location']}"
    when Net::HTTPClientError
      puts "クライアントエラー: #{response.code} #{response.message}"
    when Net::HTTPServerError
      puts "サーバーエラー: #{response.code} #{response.message}"
    else
      puts "未知のエラーレスポンス: #{response.code} #{response.message}"
    end
  end

  def generate_user_agent
    "chrome113; #{RUBY_VERSION}; #{RUBY_PLATFORM}; time=#{Time.now.to_i}"
  end

  def log_request(request)
    puts "=== リクエスト開始 ==="
    puts "Method: #{request.method}"
    puts "URI: #{request.uri}"
    puts "User-Agent: #{request['User-Agent']}"
    puts "======================"
  end

  def log_response(response)
    puts "=== レスポンス受信 ==="
    puts "Code: #{response.code}"
    puts "Message: #{response.message}"
    puts "Headers: #{response.to_hash}"
    puts "Body: #{response.body[0..200]}"
    puts "======================"
  end
end

LicenseKeyFetcher.new.fetch_license_key
