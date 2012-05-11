require 'rubygems'
require 'twitter'
require 'sinatra'
require 'redis'
require 'json'

configure do
    set :public_folder, Proc.new { File.join(root, "static") } # specify location of bootstrap etc
    services = JSON.parse(ENV['VCAP_SERVICES'])
    redis_key = services.keys.select { |svc| svc =~ /redis/i }.first
    redis = services[redis_key].first['credentials']
    redis_conf = {:host => redis['hostname'], :port => redis['port'], :password => redis['password']}
    @@redis = Redis.new redis_conf
end

disable :protection # disables Rack::Protection

helpers do
    def twitter_id(screen_name)
        Twitter.user(screen_name).id
    end

    def is_following?(a,b)
        followers = Twitter.follower_ids(twitter_id(b)).ids
        followers.include?(twitter_id(a))
    end

    def update_leaderboard(a,b)
        a_score = @@redis.hincrby 'user:scores', a, 1
        b_score = @@redis.hincrby 'user:scores', b, 1
        @@redis.zadd 'high:scores', a_score, a
        @@redis.zadd 'high:scores', b_score, b
    end

    def get_leaders
        @@redis.zrevrangebyscore('high:scores', '+inf', '-inf')[0..9]
    end
end

get '/' do
    @leaders = get_leaders
    erb :index
end

get '/follows' do
    @user1 = params[:user1]
    @user2 = params[:user2]
    @following = is_following?(@user1, @user2)
    update_leaderboard(@user1, @user2)
    erb :follows
end

