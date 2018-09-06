require 'sinatra'
require 'rack/flash'
require 'sqlite3'
require 'streamio-ffmpeg'
require 'json'
require 'omniauth'
require 'omniauth-google-oauth2'
require_relative 'credentals'
require_relative 'helpers/google_auth_helper'

class LoginScreen < Sinatra::Base
  configure do
    enable :sessions
    use OmniAuth::Builder do
      provider :google_oauth2, ENV['GOOGLE_KEY'], ENV['GOOGLE_SECRET'], { :hd => ['fout.jp', 'split-global.com']}
    end
  end
  
  helpers GoogleAuthHelper
  get '/logout' do
    session[:user] = nil
    redirect '/'
  end
  
  get '/auth/failure' do
    content_type 'text/plain'
    begin
      flash[:message] = request['message']     
      redirect '/'
    rescue StandardError
      'No Data'
    end
  end
  
  get '/auth/google_oauth2/callback' do
    begin
      session[:user] = request.env['omniauth.auth'].info.to_hash
      redirect '/'
    rescue StandardError
      'Login failure'
    end
  end
end

class App < Sinatra::Base
  helpers GoogleAuthHelper

  configure do
    enable :sessions
    use Rack::Flash
    DB = SQLite3::Database.new 'db/transcode.db'
    DB.busy_timeout(10000) # 10sec
    DB.results_as_hash = true
  end

  use LoginScreen
  before do
    unless login?
      halt "Access denied, please <a href='/auth/google_oauth2'>login</a>."
    end
  end
  
  get '/' do
    erb :form
  end

  post '/api/upload' do
    filename = params[:file][:filename]
    advertiser = params[:advertiser]
    quality = params[:quality]

    DB.execute "INSERT INTO source_videos(user_name, user_email, filename) values (?, ?, ?)",
      user_name, user_email, filename
    source_id = DB.last_insert_row_id
    
    file = params[:file][:tempfile]
    File.rename(file, "./source/source_#{source_id}.mp4")

    DB.execute "INSERT INTO transcode_jobs (source_id, filename, user_name, user_email, advertiser, quality) values (?, ?, ?, ?, ?, ?)",
      source_id, filename, user_name, user_email, advertiser, quality
    job_id = DB.last_insert_row_id

    source_video = DB.execute("SELECT * FROM source_videos WHERE source_id = ? LIMIT 1", source_id).first
    transcode_job = DB.execute("SELECT * FROM transcode_jobs WHERE job_id = ? LIMIT 1", job_id).first

    child_pid = Process.fork do
      system("bundle exec ruby transcoder.rb #{job_id}")
      Process.exit
    end
    Process.detach child_pid

    content_type :json
    return {'transcode_job': transcode_job, 'source_video': source_video}.to_json
  end

  get '/output' do
    output_id = params[:output_id]
    send_file("output/output_#{output_id}.mp4")
  end

  get '/api/source_video' do
    source_id = params[:source_id]
    content_type :json
    DB.execute("SELECT * FROM source_videos WHERE source_id = ? LIMIT 1", source_id).first.to_json
  end

  get '/api/transcode_job' do
    job_id = params[:job_id]
    content_type :json
    DB.execute("SELECT * FROM transcode_jobs WHERE job_id = ? LIMIT 1", job_id).first.to_json
  end

  get '/api/output_video' do
    output_id = params[:output_id]
    content_type :json
    DB.execute("SELECT * FROM output_videos WHERE output_id = ? LIMIT 1", output_id).first.to_json
  end

  get '/api/source_video_list' do
    content_type :json
    DB.execute("SELECT * FROM source_videos ORDER BY source_id DESC").to_json
  end

  get '/api/transcode_job_list' do
    content_type :json
    DB.execute("SELECT * FROM transcode_jobs ORDER BY job_id DESC").to_json
  end

  get '/api/output_video_list' do
    content_type :json
    DB.execute("SELECT * FROM output_videos ORDER BY output_id DESC").to_json
  end
end
