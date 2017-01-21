# frozen_string_literal: true
class RainforestCli::TestParser::ParameterizedEmbeddedTest < Struct.new(:rfml_id, :redirect, :parameters)
  def type
    :parameterized_test
  end

  def to_s
    "- #{rfml_id}(#{parameters})\n"
  end

  def has_uploadable_files?
    false
  end
end