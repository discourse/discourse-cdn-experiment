# frozen_string_literal: true

module CdnExperiment
  module ApplicationHelperExtension
    extend ActiveSupport::Concern

    %i[
      script_asset_path
      discourse_stylesheet_preload_tag
      discourse_stylesheet_link_tag
      theme_lookup
      theme_translations_lookup
      theme_js_lookup
      discourse_preload_color_scheme_stylesheets
      discourse_color_scheme_stylesheets
      client_side_setup_data
    ].each do |method_name|
      define_method(method_name) do |*args, **kwargs|
        result = super(*args, **kwargs)
        return result if !SiteSetting.cdn_experiment_enabled
        CdnExperiment.perform_gsub(result, request.env)
      end
    end
  end
end
