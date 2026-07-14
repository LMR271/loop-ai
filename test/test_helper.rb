ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Temporarily replace an instance method with `replacement` for the duration
    # of the block, then restore the original. A minimal stand-in for the mocking
    # support that minitest 6 no longer ships.
    def stub_instance_method(klass, name, replacement)
      klass.send(:alias_method, "__stub_orig_#{name}", name)
      klass.send(:define_method, name, replacement)
      yield
    ensure
      klass.send(:alias_method, name, "__stub_orig_#{name}")
      klass.send(:remove_method, "__stub_orig_#{name}")
    end
  end
end
