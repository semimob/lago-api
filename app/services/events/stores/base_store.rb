# frozen_string_literal: true

module Events
  module Stores
    class BaseStore
      def initialize(code:, subscription:, boundaries:, group: nil, event: nil)
        @code = code
        @subscription = subscription
        @boundaries = boundaries
        @group = group
        @event = event

        @aggregation_property = nil
        @numeric_property = false
      end

      def events
        raise NotImplementedError
      end

      def events_values
        raise NotImplementedError
      end

      delegate :count, to: :events

      def max
        raise NotImplementedError
      end

      def last
        raise NotImplementedError
      end

      attr_accessor :numeric_property, :aggregation_property

      protected

      attr_accessor :code, :subscription, :group, :event, :boundaries

      def from_datetime
        boundaries[:from_datetime]
      end

      def to_datetime
        boundaries[:to_datetime]
      end
    end
  end
end
