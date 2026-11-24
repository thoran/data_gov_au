# data_gov_au.gemspec

require_relative './lib/DataGovAu/VERSION'

class Gem::Specification
  def development_dependencies=(gems)
    gems.each{|gem| add_development_dependency(*gem)}
  end

  def runtime_dependencies=(gems)
    gems.each{|gem| add_runtime_dependency(*gem)}
  end
end

Gem::Specification.new do |spec|
  spec.name = 'data_gov_au'
  spec.version = DataGovAu::VERSION

  spec.summary = "A client for data.gov.au's CKAN API, and the datasets built on it."
  spec.description = "Find a dataset through data.gov.au's CKAN catalogue by its name or id, read what the catalogue says of it and of each of its resources, and download a resource once, checked against the length the catalogue reports. Built on it, the Australian Business Register's weekly ABN bulk extract, each release fetched once and kept."

  spec.author = 'thoran'
  spec.email = 'code@thoran.com'
  spec.homepage = "https://github.com/thoran/data_gov_au"
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.2'
  spec.require_paths = ['lib']

  spec.files = [
    'data_gov_au.gemspec',
    Dir['lib/**/*.rb'],
    Dir['test/**/*.rb'],
    Dir['test/fixtures/*'],
    'CHANGELOG',
    'Gemfile',
    'LICENSE',
    'Rakefile',
    'README.md',
    'TODO',
  ].flatten

  spec.runtime_dependencies = [
    'http.rb',
    'ox',
    'rubyzip',
    ['zstd-ruby', '>= 1.5.6.2'],
  ]

  spec.development_dependencies = [
    ['minitest', '~> 6.0'],
    'rake',
    'webmock',
  ]
end
