# frozen_string_literal: true
require 'rainforest'
require 'parallel'
require 'ruby-progressbar'

class RainforestCli::Uploader
  require 'rainforest_cli/uploader/file_parser'

  attr_reader :test_files, :remote_tests, :validator

  def initialize(options)
    @test_files = RainforestCli::TestFiles.new(options)
    @remote_tests = RainforestCli::RemoteTests.new(options.token)
    @validator = RainforestCli::Validator.new(options, test_files, remote_tests)
  end

  def upload
    validator.validate_with_exception!

    # Create new tests first to ensure that they can be embedded
    if new_tests.any?
      logger.info 'Syncing new tests...'
      each_in_parallel(new_tests) { |rfml_test| upload_empty_test(rfml_test) }
    end

    # Update all tests
    logger.info 'Uploading tests...'
    each_in_parallel(rfml_tests) { |rfml_test| upload_test(rfml_test) }
  end

  def create_test_obj(rfml_test)
    test_obj = {
      start_uri: rfml_test.start_uri || '/',
      title: rfml_test.title,
      site_id: rfml_test.site_id,
      description: rfml_test.description,
      source: 'rainforest-cli',
      tags: rfml_test.tags.uniq,
      rfml_id: rfml_test.rfml_id,
    }
    test_id = primary_key_dictionary[rfml_test.rfml_id]

    if rfml_test.has_uploadable?
      uploaded_files = http_client.get("/tests/#{test_id}/files")
      FileParser.new(rfml_test, test_id, uploaded_files).parse_files!
    end

    test_obj[:elements] = rfml_test.steps.map do |step|
      if step.is_a?(RainforestCli::TestParser::EmbeddedTest)
        {
          type: 'test',
          redirection: step.redirect || true,
          element: { id: primary_key_dictionary[step.rfml_id] },
        }
      else
        {
          type: 'step',
          redirection: step.redirect || true,
          element: {
            action: step.action,
            response: step.response,
          },
        }
      end
    end

    unless rfml_test.browsers.empty?
      test_obj[:browsers] = rfml_test.browsers.map do|b|
        {'state' => 'enabled', 'name' => b}
      end
    end

    test_obj
  end

  private

  def each_in_parallel(tests, &blk)
    progress_bar = ProgressBar.create(title: 'Tests', total: tests.count, format: '%a %B %p%% %t')
    Parallel.each(tests, in_threads: threads, finish: lambda { |_item, _i, _result| progress_bar.increment }) do |rfml_test|
      blk.call(rfml_test)
    end
  end

  def rfml_tests
    @rfml_tests ||= test_files.test_data
  end

  def new_tests
    @new_tests ||= rfml_tests.select { |t| primary_key_dictionary[t.rfml_id].nil? }
  end

  def primary_key_dictionary
    @primary_key_dictionary ||= remote_tests.primary_key_dictionary
  end

  def upload_empty_test(rfml_test)
    test_obj = {
      title: rfml_test.title,
      start_uri: rfml_test.start_uri,
      rfml_id: rfml_test.rfml_id,
      source: 'rainforest-cli',
    }
    rf_test = Rainforest::Test.create(test_obj)

    primary_key_dictionary[rfml_test.rfml_id] = rf_test.id
  end

  def upload_test(rfml_test)
    return unless rfml_test.steps.count > 0

    test_obj = create_test_obj(rfml_test)
    begin
      Rainforest::Test.update(primary_key_dictionary[rfml_test.rfml_id], test_obj)
    rescue => e
      logger.fatal "Error: #{rfml_test.rfml_id}: #{e}"
      exit 2
    end
  end

  def threads
    RainforestCli::THREADS
  end

  def logger
    RainforestCli.logger
  end

  def http_client
    RainforestCli.http_client
  end
end
