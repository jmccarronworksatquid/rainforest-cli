# frozen_string_literal: true
class RainforestCli::TestParser::EmbeddedTest < Struct.new(:rfml_id, :redirect)
  def type
    :test
  end

  def to_s
    "- #{rfml_id}\n"
  end

  def has_uploadable_files?
    false
  end
end
