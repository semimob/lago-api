# frozen_string_literal: true

module BillableMetrics
  module ProratedAggregations
    class SumService < BillableMetrics::ProratedAggregations::BaseService
      def initialize(**args)
        @base_aggregator = BillableMetrics::Aggregations::SumService.new(**args)

        super(**args)

        event_store.numeric_property = true
        event_store.aggregation_property = billable_metric.field_name
        # event_store.use_from_boundary = false
      end

      def aggregate(options: {})
        @options = options

        # For charges that are pay in advance on billing date we always bill full amount
        return aggregation_without_proration if event.nil? && options[:is_pay_in_advance] && !options[:is_current_usage]

        aggregation = compute_aggregation.ceil(5)
        result.full_units_number = aggregation_without_proration.aggregation if event.nil?

        if options[:is_current_usage]
          handle_current_usage(aggregation, options[:is_pay_in_advance])
        else
          result.aggregation = aggregation
        end

        result.pay_in_advance_aggregation = compute_pay_in_advance_aggregation
        result.count = aggregation_without_proration.count
        result.options = options
        result
      rescue ActiveRecord::StatementInvalid => e
        result.service_failure!(code: 'aggregation_failure', message: e.message)
      end

      def compute_per_event_prorated_aggregation
        event_store.prorated_events_values(period_duration)
      end

      protected

      attr_reader :options

      def compute_aggregation
        result = 0.0

        # NOTE: Billed on the full period
        result += (persisted_sum || 0)

        # NOTE: Added during the period
        result + (event_store.prorated_sum(period_duration:) || 0)
      end

      def persisted_sum
        event_store = event_store_class.new(
          code: billable_metric.code,
          subscription:,
          boundaries: { to_datetime: from_datetime },
          group:,
          event:,
        )

        event_store.use_from_boundary = false
        event_store.aggregation_property = billable_metric.field_name
        event_store.numeric_property = true

        event_store.prorated_sum(
          period_duration:,
          persisted_duration: Utils::DatetimeService.date_diff_with_timezone(
            from_datetime,
            to_datetime,
            subscription.customer.applicable_timezone,
          ),
        )
      end
    end
  end
end
