# frozen_string_literal: true

# name: discourse-cdn-experiment
# about: Allows A/B testing multiple CDN domains
# version: 1.0
# authors: Discourse
# url: https://github.com/discourse/discourse-cdn-experiment
# label: experiment

enabled_site_setting :cdn_experiment_enabled

module ::CdnExperiment
  ENV_KEY = "discourse-cdn-experiment-cdn-index"
  PARAM_NAME = "_cdn_index"

  def self.perform_gsub(value, env)
    if value.is_a? String
      was_html_safe = value.html_safe?
      value = value.gsub(GlobalSetting.cdn_url, app_cdn_url(env))
      value = value.gsub(GlobalSetting.s3_cdn_url, s3_cdn_url(env))
      value = value.html_safe if was_html_safe
      value
    elsif value.is_a? Hash
      value.transform_values { |hash_value| perform_gsub(hash_value, env) }
    else
      value
    end
  end

  def self.s3_cdn_url(env)
    s3_cdn_urls[current_cdn_index(env)]
  end

  def self.app_cdn_url(env)
    app_cdn_urls[current_cdn_index(env)]
  end

  def self.current_cdn_index(env)
    env[ENV_KEY] ||= begin
      request = Rack::Request.new(env)
      index_from_params(request) || index_from_ip(request)
    end
  end

  def self.index_from_params(request)
    if param = request.params[PARAM_NAME]
      index = param.to_i
      index if index >= 0 && index <= max_index
    end
  end

  def self.index_from_ip(request)
    client_ip_integer = IPAddr.new(request.ip).to_i
    seeded_random = Random.new(client_ip_integer)
    seeded_random.rand(0..max_index)
  end

  def self.max_index
    [app_cdn_urls.length, s3_cdn_urls.length].min - 1
  end

  def self.app_cdn_urls
    [GlobalSetting.cdn_url, *SiteSetting.cdn_experiment_app_cdns.split("|")]
  end

  def self.s3_cdn_urls
    [GlobalSetting.s3_cdn_url, *SiteSetting.cdn_experiment_s3_cdns.split("|")]
  end
end

after_initialize do
  require_relative "lib/cdn_experiment/application_helper_extension"
  require_relative "lib/cdn_experiment/content_security_policy_extension"

  reloadable_patch do
    ApplicationHelper.prepend(CdnExperiment::ApplicationHelperExtension)
    ContentSecurityPolicy::Default.prepend(CdnExperiment::ContentSecurityPolicyExtension)
  end

  register_anonymous_cache_key :cdnindex do
    ::CdnExperiment.current_cdn_index(@env)
  end
end
