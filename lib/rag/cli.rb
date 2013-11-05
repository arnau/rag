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
        resource['title'] = ask('Title*: ')
        break unless resource['title'].empty?
      end
      loop do
        resource['topic'] = ask('Topic*: ')
        break unless resource['topic'].empty?
      end
      resource['language'] = ask('Language: ', :limited_to => ['en', 'ca', 'es'])

      resource['identifier'] = resource['title'].downcase.gsub(/\s/, '-')
      resource['@id'] = URI.escape("/asiches/bookmarks/#{resource['identifier']}")

      url = "http://localhost:9200/#{resource['@id']}?parent=#{resource['topic']}"
      resource['topic'] = URI.escape("/asiches/topics/#{resource['topic']}")

      resource['description'] = ask('Description: ')
      resource['comment'] = ask('Comment: ')
      resource['tag'] = ask('Tags: ').split(',').map { |i| i.strip }
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


      RestClient.get(url) do |response, request, result, &block|
        if response.code == 404
          put = RestClient.put(url, resource.to_json)
        end
      end
    end

    desc 'search', 'foo'
    method_option :field, :aliases => '-f', :default => '_all'
    def search(query)
      queries = {
        topic: {
          query: {
            has_parent: {
              parent_type: 'topics',
              query: {
                term: {
                  label: 'git'
                }
              }
            }
          }
        },
        wildcard: {
          query: {
            query_string: {
              query: query,
              analyze_wildcard: true
            }
          }
        }
      }

      RestClient.post("http://localhost:9200/asiches/bookmarks/_search", data.fetch(:wildcard).to_json) do |response, request, result, &block|
        #puts response.body, response.code
        format(response)
      end
    end

    desc 'topic', 'foo'
    def topic(term)
      topic = { query: {
        has_parent: {
          parent_type: 'topics',
          query: {
            term: {
              label: term
            }
          }
        }
      }}

      RestClient.post("http://localhost:9200/asiches/_search", topic.to_json) do |response, request, result, &block|
        format(response)
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

    desc 'rebirth', 'foo'
    def rebirth
      RestClient.delete("http://localhost:9200/asiches")
      settings = BASE_PATH.join('etc/elasticsearch/settings.json')
      RestClient.put("http://localhost:9200/asiches", settings.open.read) do |response, request, result, &block|
        puts response.body, response.code
      end

      topic = {
        "@context" => "http://api.spoontaneous.net/contexts/topics.jsonld",
        "@id" => "/asiches/topics/git",
        "@type" => "Topic",
        "label" => "Git",
        "definition" => "Git is a free and open source distributed version control system designed to handle everything from small to very large projects with speed and efficiency."
      }
      RestClient.put("http://localhost:9200/asiches/topics/git", topic.to_json) do |response, request, result, &block|
        puts response.body, response.code
      end
    end


    private
    def format(response)
      data = JSON.parse(response.body)['hits']['hits'].map { |i| i['_source'] }
      data.each do |item|
        item.delete('@context')
        item.delete('@type')
        item.delete('@id')
        say(('-' * 80), :yellow)
        item = item.to_a.map do |i|
          i[1] = i[1].map { |k| "\n#{(' ' * 14)}#{set_color('-', :black)} #{k}"}.join("") if i[1].respond_to? :join
          i[1] = set_color(i[1], :yellow, :bold) if i[0] == 'source'
          i[0] = set_color(i[0], :green)
          i
        end
        print_table(item, :indent => 2)
        say("Total: #{data.size}", :red)
        say("\n")
      end
    end
  end
end
