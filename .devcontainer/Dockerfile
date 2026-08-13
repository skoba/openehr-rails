# syntax=docker/dockerfile:1
#
# Dev container for openehr-rails gem development (not the demo app --
# see docker/demo.Dockerfile for that). Builds from the same Ruby base
# image as CI/demo for consistency.

ARG RUBY_VERSION=4.0.6
FROM docker.io/library/ruby:${RUBY_VERSION}-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential git libffi-dev libsqlite3-dev libyaml-dev pkg-config curl less vim-tiny && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN gem install bundler rails --no-document

WORKDIR /workspaces/openehr-rails
