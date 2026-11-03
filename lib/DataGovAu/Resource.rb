# DataGovAu/Resource.rb
# DataGovAu::Resource

require 'fileutils'
require 'time'
require 'uri'

require 'http.rb'

require_relative './Error'

module DataGovAu
  # One file of a dataset, as the catalogue describes it.
  class Resource
    PARTIAL_CONTENT = 206
    PARTIAL_SUFFIX = '.partial'

    def name
      @resource['name']
    end

    def format
      @resource['format']
    end

    # In bytes, or nil where the catalogue leaves it out.
    def size
      @resource['size']
    end

    def url
      @resource['url']
    end

    # CKAN gives its times without a zone, and they are UTC.
    def last_modified
      @last_modified ||= @resource['last_modified'] && Time.parse("#{@resource['last_modified']}Z")
    end

    # The name data.gov.au serves the file under, which is the last segment of its URL; the resource's own name is prose, and holds a trailing space in at least one case.
    def filename
      @filename ||= File.basename(URI.parse(url).path)
    end

    # The first bytes, asked for by range, so that what a file begins with costs a few hundred bytes rather than the whole of it. A server which ignored the range would answer 200 with the whole body, which is worth stopping for: holding it is the one thing asking by range is meant to avoid.
    def first_bytes(length)
      response = get('Range' => "bytes=0-#{length - 1}")
      raise DownloadFailed, "#{url} answered #{response.code} where a range was asked for" unless response.code.to_i == PARTIAL_CONTENT
      response.body
    end

    # Written to a partial file and renamed into place once whole, so that a download cut short leaves nothing which would pass for the file. A body other than the length the catalogue reports stops here rather than at whatever reads it.
    def download(path)
      partial_path = path + PARTIAL_SUFFIX
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(partial_path, body)
      verify(partial_path)
      File.rename(partial_path, path)
      path
    end

    # Present at the length the catalogue reports. A length the catalogue leaves out cannot be checked, so presence alone stands for it.
    def held_at?(path)
      File.exist?(path) && (size.nil? || File.size(path) == size)
    end

    def to_h
      @resource
    end

    private

    def initialize(catalogue, resource)
      @catalogue = catalogue
      @resource = resource
    end

    def get(headers = {})
      HTTP.get(url, {}, {'User-Agent' => @catalogue.user_agent}.merge(headers))
    end

    def body
      response = get
      raise DownloadFailed, "#{url} answered #{response.code}" unless response.success?
      response.body
    end

    def verify(path)
      return if size.nil? || File.size(path) == size
      found = File.size(path)
      File.delete(path)
      raise DownloadFailed, "#{url} gave #{found} bytes where the catalogue reports #{size}"
    end
  end
end
