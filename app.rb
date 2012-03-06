require 'sinatra'
require 'redis'

configure do
  uri = URI.parse(ENV["REDISTOGO_URL"] || "redis://localhost:6379")
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

get '/db' do
  lines = []

  REDIS.keys("*").each do |key|
    case REDIS.type(key)
    when "string"
      lines << "#{key}: #{REDIS.get(key)}"
    when "list"
      lines << "#{key}: #{REDIS.lrange(key, 0, -1)}"
    end
  end
  
  lines.join "</br>"
end
