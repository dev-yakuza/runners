class Gem::Version
  include Comparable

  def self.create: (String | Gem::Version) -> Gem::Version
  def version: -> String
end

class Gem::Requirement
  def self.create: (Array<String> | nil) -> Gem::Requirement
  def satisfied_by?: (Gem::Version) -> bool
end
