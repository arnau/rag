# encoding: UTF-8

require 'json'
require 'pathname'

require 'bundler'
Bundler.require

#require 'thor/actions'
require 'rag/version'

module Rag
  # The base path.
  BASEPATH = File.dirname(__FILE__)
end
