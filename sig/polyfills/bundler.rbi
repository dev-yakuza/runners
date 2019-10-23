class Bundler::LazySpecification
  attr_reader name: String
  attr_reader version: Gem::Version
end

class Bundler::LockfileParser
  def initialize: (String) -> any
  def specs: -> Array<Bundler::LazySpecification>
end
