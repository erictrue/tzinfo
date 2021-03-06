# frozen_string_literal: true

require File.join(File.expand_path(File.dirname(__FILE__)), 'test_utils')
require 'tmpdir'

include TZInfo

class TCDataSource < Minitest::Test
  class InitDataSource < DataSource
  end

  class DummyDataSource < DataSource
  end

  class TestDataSource < DataSource
    attr_reader :called

    def initialize
      super
      @called = 0
    end
  end

  class GetTimezoneInfoTestDataSource < TestDataSource
    protected

    def load_timezone_info(identifier)
      @called += 1
      raise InvalidTimezoneIdentifier, identifier if identifier == 'Test/Invalid'
      DataSources::TimezoneInfo.new(identifier)
    end
  end

  class GetCountryInfoTestDataSource < TestDataSource
    protected

    def load_country_info(code)
      @called += 1
      raise InvalidCountryCode, code if code == 'XX'
      DataSources::CountryInfo.new(code, "Country #{code}", [])
    end
  end

  class GetTimezoneIdentifiersTestDataSource < DataSource
    attr_reader :data_timezone_identifiers_called
    attr_reader :linked_timezone_identifiers_called

    def initialize(data_timezone_identifiers, linked_timezone_identifiers)
      @data_timezone_identifiers = data_timezone_identifiers.each {|i| i.freeze}.freeze
      @linked_timezone_identifiers = linked_timezone_identifiers.each {|i| i.freeze}.freeze
      @data_timezone_identifiers_called = 0
      @linked_timezone_identifiers_called = 0
    end

    def data_timezone_identifiers
      @data_timezone_identifiers_called += 1
      @data_timezone_identifiers
    end

    def linked_timezone_identifiers
      @linked_timezone_identifiers_called += 1
      @linked_timezone_identifiers
    end
  end

  class ValidTimezoneIdentifierTestDataSource < DataSource
    attr_reader :timezone_identifiers

    def initialize(timezone_identifiers)
      super()
      @timezone_identifiers = timezone_identifiers.freeze
    end

    def call_valid_timezone_identifier?(identifier)
      valid_timezone_identifier?(identifier)
    end
  end

  def setup
    @orig_data_source = DataSource.get
    DataSource.set(InitDataSource.new)
    @orig_search_path = DataSources::ZoneinfoDataSource.search_path.clone
  end

  def teardown
    DataSource.set(@orig_data_source)
    DataSources::ZoneinfoDataSource.search_path = @orig_search_path
  end

  def test_get
    data_source = DataSource.get
    assert_kind_of(InitDataSource, data_source)
  end

  def test_get_default_ruby_only
    code = <<-EOF
      require 'tmpdir'

      begin
        Dir.mktmpdir('tzinfo_test_dir') do |dir|
          TZInfo::DataSources::ZoneinfoDataSource.search_path = [dir]

          puts TZInfo::DataSource.get.class
        end
      rescue Exception => e
        puts "Unexpected exception: \#{e}"
      end
    EOF

    assert_sub_process_returns(['TZInfo::DataSources::RubyDataSource'], code, [TZINFO_TEST_DATA_DIR])
  end

  def test_get_default_zoneinfo_only
    code = <<-EOF
      require 'tmpdir'

      begin
        Dir.mktmpdir('tzinfo_test_dir') do |dir|
          TZInfo::DataSources::ZoneinfoDataSource.search_path = [dir, '#{TZINFO_TEST_ZONEINFO_DIR}']

          puts TZInfo::DataSource.get.class
          puts TZInfo::DataSource.get.zoneinfo_dir
        end
      rescue Exception => e
        puts "Unexpected exception: \#{e}"
      end
    EOF

    assert_sub_process_returns(
      ['TZInfo::DataSources::ZoneinfoDataSource', TZINFO_TEST_ZONEINFO_DIR],
      code)
  end

  def test_get_default_ruby_and_zoneinfo
    code = <<-EOF
      begin
        TZInfo::DataSources::ZoneinfoDataSource.search_path = ['#{TZINFO_TEST_ZONEINFO_DIR}']

        puts TZInfo::DataSource.get.class
      rescue Exception => e
        puts "Unexpected exception: \#{e}"
      end
    EOF

    assert_sub_process_returns(['TZInfo::DataSources::RubyDataSource'], code, [TZINFO_TEST_DATA_DIR])
  end

  def test_get_default_no_data
    code = <<-EOF
      require 'tmpdir'

      begin
        Dir.mktmpdir('tzinfo_test_dir') do |dir|
          TZInfo::DataSources::ZoneinfoDataSource.search_path = [dir]

          begin
            data_source = TZInfo::DataSource.get
            puts "No exception raised, returned \#{data_source} instead"
          rescue Exception => e
            puts e.class
          end
        end
      rescue Exception => e
        puts "Unexpected exception: \#{e}"
      end
    EOF

    assert_sub_process_returns(['TZInfo::DataSourceNotFound'], code)
  end

  def test_set_instance
    DataSource.set(DummyDataSource.new)
    data_source = DataSource.get
    assert_kind_of(DummyDataSource, data_source)
  end

  def test_set_standard_ruby
    DataSource.set(:ruby)
    data_source = DataSource.get
    assert_kind_of(DataSources::RubyDataSource, data_source)
  end

  def test_set_standard_ruby_not_found
    code = <<-EOF
      begin
        TZInfo::DataSources::RubyDataSource.set(:ruby)
        puts 'No exception raised'
      rescue Exception => e
        puts e.class
        puts e.message
      end
    EOF

    assert_sub_process_returns([
      'TZInfo::DataSources::TZInfoDataNotFound',
      'TZInfo::Data could not be found (require \'tzinfo/data\' failed).'], code)
  end

  def test_set_standard_zoneinfo_search
    Dir.mktmpdir('tzinfo_test_dir') do |dir|
      FileUtils.touch(File.join(dir, 'iso3166.tab'))
      FileUtils.touch(File.join(dir, 'zone.tab'))

      DataSources::ZoneinfoDataSource.search_path = [dir]

      DataSource.set(:zoneinfo)
      data_source = DataSource.get
      assert_kind_of(DataSources::ZoneinfoDataSource, data_source)
      assert_equal(dir, data_source.zoneinfo_dir)
    end
  end

  def test_set_standard_zoneinfo_search_zone1970
    Dir.mktmpdir('tzinfo_test_dir') do |dir|
      FileUtils.touch(File.join(dir, 'iso3166.tab'))
      FileUtils.touch(File.join(dir, 'zone1970.tab'))

      DataSources::ZoneinfoDataSource.search_path = [dir]

      DataSource.set(:zoneinfo)
      data_source = DataSource.get
      assert_kind_of(DataSources::ZoneinfoDataSource, data_source)
      assert_equal(dir, data_source.zoneinfo_dir)
    end
  end

  def test_set_standard_zoneinfo_explicit
    Dir.mktmpdir('tzinfo_test_dir') do |dir|
      FileUtils.touch(File.join(dir, 'iso3166.tab'))
      FileUtils.touch(File.join(dir, 'zone.tab'))

      DataSource.set(:zoneinfo, dir)
      data_source = DataSource.get
      assert_kind_of(DataSources::ZoneinfoDataSource, data_source)
      assert_equal(dir, data_source.zoneinfo_dir)
    end
  end

  def test_set_standard_zoneinfo_explicit_zone1970
    Dir.mktmpdir('tzinfo_test_dir') do |dir|
      FileUtils.touch(File.join(dir, 'iso3166.tab'))
      FileUtils.touch(File.join(dir, 'zone.tab'))

      DataSource.set(:zoneinfo, dir)
      data_source = DataSource.get
      assert_kind_of(DataSources::ZoneinfoDataSource, data_source)
      assert_equal(dir, data_source.zoneinfo_dir)
    end
  end

  def test_set_standard_zoneinfo_explicit_alternate_iso3166
    Dir.mktmpdir('tzinfo_test_dir') do |dir|
      zoneinfo_dir = File.join(dir, 'zoneinfo')
      tab_dir = File.join(dir, 'tab')

      FileUtils.mkdir(zoneinfo_dir)
      FileUtils.mkdir(tab_dir)

      FileUtils.touch(File.join(zoneinfo_dir, 'zone.tab'))

      iso3166_file = File.join(tab_dir, 'iso3166.tab')
      FileUtils.touch(iso3166_file)

      DataSource.set(:zoneinfo, zoneinfo_dir, iso3166_file)
      data_source = DataSource.get
      assert_kind_of(DataSources::ZoneinfoDataSource, data_source)
      assert_equal(zoneinfo_dir, data_source.zoneinfo_dir)
    end
  end

  def test_set_standard_zoneinfo_search_not_found
    Dir.mktmpdir('tzinfo_test_dir') do |dir|
      DataSources::ZoneinfoDataSource.search_path = [dir]

      error = assert_raises(DataSources::ZoneinfoDirectoryNotFound) do
        DataSource.set(:zoneinfo)
      end
      assert_equal('None of the paths included in TZInfo::DataSources::ZoneinfoDataSource.search_path are valid zoneinfo directories.', error.message)

      assert_kind_of(InitDataSource, DataSource.get)
    end
  end

  def test_set_standard_zoneinfo_explicit_invalid
    Dir.mktmpdir('tzinfo_test_dir') do |dir|
      error = assert_raises(DataSources::InvalidZoneinfoDirectory) do
        DataSource.set(:zoneinfo, dir)
      end
      assert_equal("#{dir} is not a directory or doesn't contain a iso3166.tab file and a zone1970.tab or zone.tab file.", error.message)

      assert_kind_of(InitDataSource, DataSource.get)
    end
  end

  def test_set_standard_zoneinfo_wrong_arg_count
    assert_raises(ArgumentError) do
      DataSource.set(:zoneinfo, 1, 2, 3)
    end

    assert_kind_of(InitDataSource, DataSource.get)
  end

  def test_set_invalid_datasource_type
    error = assert_raises(ArgumentError) { DataSource.set(:other) }
    assert_equal('data_source_or_type must be a DataSource instance or a data source type (:ruby or :zoneinfo)', error.message)
  end

  def test_set_not_a_datasource
    error = assert_raises(ArgumentError) { DataSource.set(Object.new) }
    assert_equal('data_source_or_type must be a DataSource instance or a data source type (:ruby or :zoneinfo)', error.message)
  end

  def test_get_timezone_info
    ds = GetTimezoneInfoTestDataSource.new
    info = ds.get_timezone_info('Test/Simple')
    assert_equal('Test/Simple', info.identifier)
    assert_equal(1, ds.called)
  end

  def test_get_timezone_info_caches_result
    ds = GetTimezoneInfoTestDataSource.new
    info = ds.get_timezone_info('Test/Cache')
    assert_equal('Test/Cache', info.identifier)
    assert_same(info, ds.get_timezone_info('Test/Cache'))
    assert_equal(1, ds.called)
  end

  def test_get_timezone_info_invalid_identifier
    ds = GetTimezoneInfoTestDataSource.new
    error = assert_raises(InvalidTimezoneIdentifier) { ds.get_timezone_info('Test/Invalid') }
    assert_equal('Test/Invalid', error.message)
    assert(1, ds.called)
  end

  def test_timezone_identifiers
    ds = GetTimezoneIdentifiersTestDataSource.new(['Test/Aaa', 'Test/Ccc'], ['Test/Bbb'])
    result = ds.timezone_identifiers
    assert_kind_of(Array, result)
    assert_equal(['Test/Aaa', 'Test/Bbb', 'Test/Ccc'], result)
    assert(result.frozen?)
    assert(result.all?(&:frozen?))
    assert_equal(1, ds.data_timezone_identifiers_called)
    assert_equal(1, ds.linked_timezone_identifiers_called)
  end

  def test_timezone_identifiers_caches_result
    ds = GetTimezoneIdentifiersTestDataSource.new(['Test/Aaa', 'Test/Ccc'], ['Test/Bbb'])
    result = ds.timezone_identifiers
    assert_same(result, ds.timezone_identifiers)
    assert_equal(1, ds.data_timezone_identifiers_called)
    assert_equal(1, ds.linked_timezone_identifiers_called)
  end

  def test_timezone_identifiers_returns_data_array_if_linked_is_empty
    data_identifiers = ['Test/Aaa', 'Test/Ccc']
    ds = GetTimezoneIdentifiersTestDataSource.new(data_identifiers, [])
    result = ds.timezone_identifiers
    assert_same(data_identifiers, result)
    assert_equal(1, ds.data_timezone_identifiers_called)
    assert_equal(1, ds.linked_timezone_identifiers_called)
  end

  def test_timezone_identifiers_caches_result_if_linked_is_empty
    data_identifiers = ['Test/Aaa', 'Test/Ccc']
    ds = GetTimezoneIdentifiersTestDataSource.new(data_identifiers, [])
    result = ds.timezone_identifiers
    assert_same(data_identifiers, result)
    assert_same(data_identifiers, ds.timezone_identifiers)
    assert_equal(1, ds.data_timezone_identifiers_called)
    assert_equal(1, ds.linked_timezone_identifiers_called)
  end

  def abstract_test(method, public, *args)
    ds = DataSource.new
    error = assert_raises(InvalidDataSource) { ds.public_send(*([public ? :public_send : :send, method] + args)) }
    assert_equal("#{method} not defined", error.message)
  end

  def test_data_timezone_identifiers
    abstract_test(:data_timezone_identifiers, true)
  end

  def test_linked_timezone_identifiers
    abstract_test(:linked_timezone_identifiers, true)
  end

  def test_get_country_info
    ds = GetCountryInfoTestDataSource.new
    info = ds.get_country_info('CC')
    assert_equal('CC', info.code)
    assert_equal(1, ds.called)
  end

  def test_get_country_info_invalid_identifier
    ds = GetCountryInfoTestDataSource.new
    error = assert_raises(InvalidCountryCode) { ds.get_country_info('XX') }
    assert_equal('XX', error.message)
    assert_equal(1, ds.called)
  end

  def test_country_codes
    abstract_test(:country_codes, true)
  end

  def test_to_s
    assert_equal('Default DataSource', DataSource.new.to_s)
  end

  def test_inspect
    assert_equal('#<TCDataSource::TestDataSource>', TestDataSource.new.inspect)
  end

  def test_load_timezone_info
    abstract_test(:load_timezone_info, false, 'Test/Identifier')
  end

  def test_load_country_info
    abstract_test(:load_country_info, false, 'CC')
  end

  def test_valid_timezone_identifier
    identifiers = ['America/Argentina/Buenos_Aires', 'America/New_York', 'Australia/Melbourne', 'EST', 'Etc/UTC', 'Europe/Paris', 'Europe/Prague', 'UTC']
    ds = ValidTimezoneIdentifierTestDataSource.new(identifiers.sort)
    assert_same(identifiers[0], ds.call_valid_timezone_identifier?('America/Argentina/Buenos_Aires'))
    assert_same(identifiers[1], ds.call_valid_timezone_identifier?('America/New_York'))
    assert_same(identifiers[2], ds.call_valid_timezone_identifier?('Australia/Melbourne'))
    assert_same(identifiers[3], ds.call_valid_timezone_identifier?('EST'))
    assert_same(identifiers[4], ds.call_valid_timezone_identifier?('Etc/UTC'))
    assert_same(identifiers[5], ds.call_valid_timezone_identifier?('Europe/Paris'))
    assert_same(identifiers[6], ds.call_valid_timezone_identifier?('Europe/Prague'))
    assert_same(identifiers[7], ds.call_valid_timezone_identifier?('UTC'))
    assert_nil(ds.call_valid_timezone_identifier?('Aaa/Test'))
    assert_nil(ds.call_valid_timezone_identifier?('Americax/New_York'))
    assert_nil(ds.call_valid_timezone_identifier?('Europe/London'))
    assert_nil(ds.call_valid_timezone_identifier?('Europe/Parisx'))
    assert_nil(ds.call_valid_timezone_identifier?('PST'))
    assert_nil(ds.call_valid_timezone_identifier?('Zzz/Test'))
    assert_nil(ds.call_valid_timezone_identifier?(nil))
    assert_nil(ds.call_valid_timezone_identifier?(Object.new))
  end
end
