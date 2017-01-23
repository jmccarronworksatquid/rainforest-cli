# frozen_string_literal: true
class RainforestCli::TestParser::ParameterizedEmbeddedTest < Struct.new(:rfml_id, :redirect, :parameters)
  def type
    :parameterized_test
  end

  def to_s
    "- #{rfml_id}#{parameters}\n"
  end
  
  def expand_to_steps(all_tests)
    steps = []
    # find the test referenced by the embedded rmfl_id
    embedded_test = all_tests.select {|t| t.rfml_id == self.rfml_id}
    if embedded_test.any?
      embedded_test[0].steps.each do |step|
        if step.type == :parameterized_test
          # TODO check for circular dependencies before potentially dying on the stack here (see validator.has_circular_dependencies?)
          step.expand_to_steps(all_tests).each do |s|
            steps.push(substitute_parameters(s))
          end
        elsif step.type == :step
          steps.push(substitute_parameters(step))
        end
      end
    end
    # else
    # TODO error bad embed rfml_id abort!
    return steps
  end
  
  def substitute_parameters(step)
    action = step.action
    response = step.response
    parameters.each_with_index do |substitution,index|
      action = action.gsub("\$" + (index + 1).to_s, substitution)
      response = response.gsub("\$" + (index + 1).to_s, substitution)
    end
    return RainforestCli::TestParser::Step.new(action,response,step.redirect)
  end

  def has_uploadable_files?
    false
  end
end