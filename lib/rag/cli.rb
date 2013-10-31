# encoding: UTF-8

module Rag
  BASE_PATH = Pathname.new(File.expand_path(File.join File.dirname(__FILE__), '..', '..'))
  class Cli < Thor
    include Thor::Actions

    #def initialize(*)
      #super
    #end
    desc 'version', 'Prints the version'
    def version
      puts "Rag version #{Rag::VERSION}"
    end
    map %w(-v --version) => :version

    desc 'add', 'Adds a bookmark'
    def add(uri)
      resource = {
        '@context' => 'http://api.spoontaneous.net/contexts/bookmarks.jsonld',
        '@type' => 'Bookmark',
        'source' => uri,
        'created' => Time.now.getutc.to_datetime.iso8601.to_s
      }

      loop do
        resource['title'] = ask('Title: ')
        break unless resource['title'].empty?
      end

      resource['language'] = ask('Language: ', :limited_to => ['eng', 'cat', 'spa'])
      resource['identifier'] = resource['title'].downcase.gsub(/\s/, '-')
      resource['@id'] = "/asiches/bookmarks/#{resource['identifier']}"
      resource['keyword'] = ask('Keywords: ').split(',').map { |i| i.strip }
      resource['reference'] = [ask('Reference: ')]
      if resource['reference'].first.empty?
        resource.delete('reference')
      else
        loop do
          answer = ask('more references?')
          break if answer.empty? or answer == 'no'
          resource['reference'].push(answer)
        end
      end
      resource.reject! { |k, v| v.empty? }
      say JSON.generate(resource), :green

      url = "http://localhost:9200/#{resource['@id']}"

      RestClient.get(url) do |response, request, result, &block|
        if response.code == 404
          put = RestClient.put(url, resource.to_json)
        end
      end
    end

    desc 'exists', 'foo'
    def exists(id)
      RestClient.get("http://localhost:9200/asiches/bookmarks/#{id}") do |response, request, result, &block|
        puts response.body, response.code, response.headers.inspect
      end
    end

    desc 'delete', 'foo'
    def delete(id)
      RestClient.delete("http://localhost:9200/asiches/bookmarks/#{id}")
    end

  end
end