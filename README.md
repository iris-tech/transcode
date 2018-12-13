# transcode
video file transcoder

## setup
```
$ cd /path/to/transcoder
$ bundle install
$ bundle exec rackup
```

### with docker
```
$ brew cask install docker
$ docker build -t iris:transcode:${version:- 0.0.1} .
$ docker run -p 9292:9292 iris/transcode:${version:- 0.0.1}
```
