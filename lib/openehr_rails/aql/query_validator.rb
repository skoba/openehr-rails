# frozen_string_literal: true

require 'openehr/aql'

module OpenehrRails
  module Aql
    # Pre-validates an AQL query against the openehr gem's known execution
    # gaps (parses fine, raises OpenEHR::AQL::ExecutionError or silently
    # misbehaves at run time), so callers (Model.aql, the REST endpoint, the
    # admin console) can surface a specific, actionable error instead of a
    # raw engine failure. See the openehr gem's own README/CHANGELOG for the
    # authoritative, up-to-date list of what the engine can execute.
    class QueryValidator
      VERSION_CLASS_NAMES = %w[VERSION LATEST_VERSION ALL_VERSIONS VERSIONED_COMPOSITION].freeze

      def self.validate!(aql_string)
        new(aql_string).validate!
      end

      def initialize(aql_string)
        @aql_string = aql_string
      end

      def validate!
        query = parse
        check_from_clause(query.from_clause)
        check_select_clause(query.select_clause)
        check_where_clause(query.where_clause)
        query
      end

      private

      def parse
        OpenEHR::AQL.parse(@aql_string)
      rescue OpenEHR::AQL::ParseError, OpenEHR::AQL::SemanticError => e
        raise InvalidQuery, e.message
      end

      def check_from_clause(from_clause)
        return unless from_clause

        walk_containment(from_clause.containment)
      end

      def walk_containment(node)
        case node
        when OpenEHR::AQL::Model::Containment
          check_class_expression(node.parent)
          walk_containment(node.child)
        when OpenEHR::AQL::Model::ContainmentAnd, OpenEHR::AQL::Model::ContainmentOr
          walk_containment(node.left)
          walk_containment(node.right)
        when OpenEHR::AQL::Model::ClassExpression
          check_class_expression(node)
        end
      end

      def check_class_expression(class_expr)
        if VERSION_CLASS_NAMES.include?(class_expr.class_name)
          raise UnsupportedFeature,
                "#{class_expr.class_name} is permanently unsupported (version-aware queries are out of scope)"
        end
        check_predicate(class_expr.predicate, class_expr.class_name)
      end

      def check_predicate(predicate, class_name)
        case predicate
        when OpenEHR::AQL::Model::StandardPredicate, OpenEHR::AQL::Model::NodePredicate
          raise UnsupportedFeature,
                "CONTAINS #{class_name} with a standardPredicate/nodePredicate is not supported yet " \
                '(only the archetype predicate form, e.g. [openEHR-EHR-OBSERVATION.x.v1])'
        when OpenEHR::AQL::Model::PredicateAnd, OpenEHR::AQL::Model::PredicateOr
          check_predicate(predicate.left, class_name)
          check_predicate(predicate.right, class_name)
        end
      end

      def check_select_clause(select_clause)
        return unless select_clause

        aggregate, plain = select_clause.columns.partition do |column|
          column.expression.is_a?(OpenEHR::AQL::Model::AggregateFunctionCall)
        end
        return if aggregate.empty? || plain.empty?

        raise UnsupportedFeature, 'mixing aggregate and non-aggregate columns in the same SELECT is not supported'
      end

      def check_where_clause(where_clause)
        return unless where_clause

        walk_where(where_clause.expression)
      end

      def walk_where(node)
        case node
        when OpenEHR::AQL::Model::AndExpr, OpenEHR::AQL::Model::OrExpr
          walk_where(node.left)
          walk_where(node.right)
        when OpenEHR::AQL::Model::NotExpr
          walk_where(node.operand)
        when OpenEHR::AQL::Model::LikeExpr
          raise UnsupportedFeature, 'LIKE is parsed but not yet executable'
        when OpenEHR::AQL::Model::MatchesExpr
          raise UnsupportedFeature, 'MATCHES is parsed but not yet executable'
        when OpenEHR::AQL::Model::Comparison
          check_operand(node.left)
          check_operand(node.right)
        end
      end

      def check_operand(operand)
        return unless operand.is_a?(OpenEHR::AQL::Model::FunctionCall) ||
                      operand.is_a?(OpenEHR::AQL::Model::TerminologyFunctionCall)

        raise UnsupportedFeature, 'generic function calls in WHERE are parsed but not yet executable ' \
                                   '(aggregate functions in SELECT - COUNT/MIN/MAX/AVG/SUM - are fine)'
      end
    end
  end
end
