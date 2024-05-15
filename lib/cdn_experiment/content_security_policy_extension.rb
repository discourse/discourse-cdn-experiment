# frozen_string_literal: true

module CdnExperiment
  module ContentSecurityPolicyExtension
    extend ActiveSupport::Concern

    def script_assets(*args, **kwargs)
      entries = super
      return entries if !SiteSetting.cdn_experiment_enabled
      additional_entries = []
      entries.each do |entry|
        if entry.include?(GlobalSetting.cdn_url)
          CdnExperiment.app_cdn_urls[1..].each do |cdn_url|
            additional_entries << entry.gsub(GlobalSetting.cdn_url, cdn_url)
          end
        elsif entry.include?(GlobalSetting.s3_cdn_url)
          CdnExperiment.s3_cdn_urls[1..].each do |s3_cdn_url|
            additional_entries << entry.gsub(GlobalSetting.s3_cdn_url, s3_cdn_url)
          end
        end
      end
      [*entries, *additional_entries]
    end
  end
end
