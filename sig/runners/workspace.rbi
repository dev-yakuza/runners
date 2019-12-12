class Runners::Workspace
  attr_reader options: Options
  attr_reader working_dir: Pathname
  attr_reader trace_writer: TraceWriter

  def self.prepare: (options: Options, working_dir: Pathname, trace_writer: TraceWriter) -> instance
  def initialize: (options: Options, working_dir: Pathname, trace_writer: TraceWriter) -> any
  def open: <'a> () { (Pathname?, Changes) -> 'a } -> 'a
  def prepare_ssh: <'a> () { (Pathname?) -> 'a } -> 'a
  def prepare_base_source: (Pathname) -> void
  def prepare_head_source: (Pathname) -> void
  def decrypt: <'a> (Pathname, String?) { (Pathname) -> 'a } -> 'a
  def decrypt_by_openssl: (Pathname, String, Pathname) -> void
  def extract: (Pathname, Pathname) -> void
  def archive_source: () -> Options::ArchiveSource
  def git_source: () -> Options::GitSource
  def root_tmp_dir: () -> Pathname
  def patches: () -> GitDiffParser::Patches?
end

class Runners::Workspace::HTTP < Workspace
  def prepare_base_source: (Pathname) -> void
  def prepare_head_source: (Pathname) -> void
  def provision: (URI, Pathname, String?) -> void
  def download: <'a> (URI) { (any) -> 'a } -> 'a
  def retryable_sleep: (Integer) -> Integer
end

class Runners::Workspace::File < Workspace
  def prepare_base_source: (Pathname) -> void
  def prepare_head_source: (Pathname) -> void
  def provision: (Pathname, Pathname, String?) -> void
end

class Runners::Workspace::Git < Workspace
  def prepare_base_source: (Pathname) -> void
  def prepare_head_source: (Pathname) -> void
  def provision: (String, Pathname) -> void
  def git_directory: () -> Pathname
  def remote_url: () -> URI
  def git_fetch_args: () -> Array<String>
end
