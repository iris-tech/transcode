drop table if exists source_videos;
create table source_videos (
  source_id integer not null primary key,
  upload_date date default current_date not null,
  user_name text not null,
  user_email text not null,
  filename text not null,
  modified timestamp default current_timestamp not null,
  created timestamp default current_timestamp not null
);

drop table if exists transcode_jobs;
create table transcode_jobs (
  job_id integer not null primary key,
  source_id integer not null,
  output_id integer default null,
  user_name text not null,
  user_email text not null,
  advertiser text not null,
  filename text not null,
  quality text not null,
  log_path1 text not null default '',
  log_path2 text not null default '',
  status text not null default 'start',
  progress integer not null default 0,
  modified timestamp default current_timestamp not null,
  created timestamp default current_timestamp not null
);

drop table if exists output_videos;
create table output_videos (
  output_id integer not null primary key,
  source_id integer not null,
  job_id integer_not null,
  modified timestamp default current_timestamp not null,
  created timestamp default current_timestamp not null
);
