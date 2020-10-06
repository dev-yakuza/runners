module Runners::RecommendedConfig : Processor
  def warn_recommended_config_file_release: (String, String) -> void
  def deploy_recommended_config_file: (String) -> void

  # private
  def exists_in_repository?: (String) -> bool
end
