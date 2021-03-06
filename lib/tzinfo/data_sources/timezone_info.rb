# frozen_string_literal: true

module TZInfo
  module DataSources
    # Represents a timezone defined by a data source.
    class TimezoneInfo

      # The timezone identifier.
      attr_reader :identifier

      # Constructs a new TimezoneInfo with an identifier.
      #
      # The passed in identifer instance will be frozen.
      #
      # Raises ArgumentError if identifier is nil.
      def initialize(identifier)
        raise ArgumentError, 'identifier must not be nil' unless identifier
        @identifier = identifier.freeze
      end

      # Returns the internal object state as a programmer-readable string.
      def inspect
        "#<#{self.class}: #@identifier>"
      end

      # Constructs a Timezone instance for the timezone represented by this
      # TimezoneInfo.
      def create_timezone
        raise_not_implemented('create_timezone')
      end

      private

      def raise_not_implemented(method_name)
        raise NotImplementedError, "Subclasses must override #{method_name}"
      end
    end
  end
end
