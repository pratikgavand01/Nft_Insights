FROM ruby:3.0.0

RUN mkdir -p /usr/src/app

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs redis-server postgresql-client
RUN apt-get install -y cron
RUN apt install nano

WORKDIR /usr/src/app

ENV RAILS_ENV production
#ENV RAILS_SERVE_STATIC_FILES true
#ENV RAILS_LOG_TO_STDOUT true

RUN gem install bundler:2.2.3

COPY Gemfile /usr/src/app/
COPY Gemfile.lock /usr/src/app/

RUN bundle install
RUN bundle update rake

COPY . /usr/src/app

# Add a script to be executed every time the container starts.