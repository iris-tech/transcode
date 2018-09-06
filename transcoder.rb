require 'streamio-ffmpeg'
require 'sqlite3'
require 'json'
require 'FileUtils'

DB = SQLite3::Database.new 'db/transcode.db'
DB.busy_timeout(10000) # 10sec
DB.results_as_hash = true

def update_status(job_id, status)
  DB.execute('UPDATE transcode_jobs SET status = ? WHERE job_id = ?', status, job_id)
end

def update_progress(job_id, progress)
  DB.execute('UPDATE transcode_jobs SET progress = ? WHERE job_id = ?', progress, job_id)
end

def transcode(job_id)
  options = {
    'High': %w(-y -f mp4 -s 1920x1080 -movflags +faststart -vcodec libx264 -b:v 4096k -bt 4096k -af loudnorm=I=-24 -acodec aac -async 1 -threads 0),
    'Mid': %w(-y -f mp4 -s 1920x1080 -movflags +faststart -vcodec libx264 -b:v 2048k -bt 2048k -af loudnorm=I=-24 -acodec aac -async 1 -threads 0),
    'Low': %w(-y -f mp4 -s 1920x1080 -movflags +faststart -vcodec libx264 -b:v 1024k -bt 1024k -af loudnorm=I=-24 -acodec aac -async 1 -threads 0),
  }
  query = <<~EOQ
    SELECT
      transcode_jobs.job_id,
      transcode_jobs.user_name,
      transcode_jobs.user_email,
      transcode_jobs.advertiser,
      transcode_jobs.filename,
      transcode_jobs.quality,
      transcode_jobs.status,
      transcode_jobs.progress,
      source_videos.source_id,
      source_videos.upload_date
    FROM
      transcode_jobs
    INNER JOIN source_videos ON transcode_jobs.source_id = source_videos.source_id
    WHERE transcode_jobs.job_id = ? LIMIT 1
  EOQ

  job     = DB.execute(query, job_id).first
  source_id = job['source_id']

  option  = options[job['quality'].to_sym]
  in_file = "source/source_#{source_id}.mp4"
  movie   = FFMPEG::Movie.new(in_file)
  progress = 0.0

  # pass 1
  update_status(job_id, 'transcoding pass1')
  movie.transcode("tmp/transcode_#{job_id}.mp4", option.push('-pass').push('1').push('-passlogfile').push("tmp/#{job_id}.log")) do |prgrs|
    progress = (prgrs * 100 / 2).round(1)
    update_progress(job_id, progress)
  end

  # pass 2
  update_status(job_id, 'transcoding pass2')
  movie.transcode("tmp/transcode_#{job_id}.mp4", option.push('-pass').push('2').push('-passlogfile').push("tmp/#{job_id}.log")) do |prgrs|
    progress = 50 + (prgrs * 100 / 2).round(1)
    update_progress(job_id, progress)
  end
  progress = 100
  update_progress(job_id, progress)
  update_status(job_id, 'complete')

  # output record
  DB.execute "INSERT INTO output_videos (source_id, job_id) values (?, ?)",
    source_id, job_id
  output_id = DB.last_insert_row_id
  DB.execute "UPDATE transcode_jobs SET output_id = ? WHERE job_id = ?", output_id, job_id

  # move to output
  File.rename("tmp/transcode_#{job_id}.mp4", "output/output_#{output_id}.mp4")

  # clean up passlogfile
  FileUtils.rm Dir.glob("tmp/#{job_id}.log*")
end

job_id = ARGV[0].to_i
transcode(job_id)
