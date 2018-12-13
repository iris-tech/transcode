FROM alpine:3.8

ENV APP_ROOT /var/app/transcode

RUN set -ex \
    && apk --update --no-cache add --virtual .build-dependencies \
      build-base \
      gcc \
      libc-dev \
      ruby-dev \
      make \
    && apk --update --no-cache add \
      ffmpeg=3.4.4-r1 \
      ruby-full=2.5.2-r0 \
      sqlite-dev \
      sqlite \
    && rm -rf /var/lib/apt/lists/*

COPY . $APP_ROOT
WORKDIR $APP_ROOT

RUN gem install bundler --no-rdoc --no-ri

ENV BUNDLE_JOBS 4
RUN bundle install

RUN apk del .build-dependencies

RUN scripts/initdb.sh

EXPOSE 9292
CMD bundle exec rackup -o 0.0.0.0