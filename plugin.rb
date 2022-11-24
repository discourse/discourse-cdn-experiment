# frozen_string_literal: true

# name: discourse-cdn-experiment
# about: Allows A/B testing multiple CDN domains
# version: 1.0
# authors: Discourse
# url: https://github.com/discourse/discourse-cdn-experiment

enabled_site_setting :cdn_experiment_enabled

module ::CdnExperiment
  ENV_KEY = "discourse-cdn-experiment-cdn-index"

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
    env[ENV_KEY] ||= pick_new_cdn_index(env)
  end

  def self.pick_new_cdn_index(env)
    request = Rack::Request.new(env)
    client_ip_integer = IPAddr.new(request.ip).to_i
    seeded_random = Random.new(client_ip_integer)
    min_array_length = [app_cdn_urls.length, s3_cdn_urls.length].min
    seeded_random.rand(0...min_array_length)
  end

  def self.app_cdn_urls
    [GlobalSetting.cdn_url, *SiteSetting.cdn_experiment_app_cdns.split("|")]
  end

  def self.s3_cdn_urls
    [GlobalSetting.s3_cdn_url, *SiteSetting.cdn_experiment_s3_cdns.split("|")]
  end
end

after_initialize do
  reloadable_patch do
    ApplicationHelper.class_eval do
      [
        :script_asset_path,
        :discourse_stylesheet_preload_tag,
        :discourse_stylesheet_link_tag,
        :theme_lookup,
        :theme_translations_lookup,
        :theme_js_lookup,
        :discourse_preload_color_scheme_stylesheets,
        :discourse_color_scheme_stylesheets,
        :client_side_setup_data
      ].each do |method_name|
        alias_method :"orig_#{method_name}", :"#{method_name}"
        define_method(method_name) do |*args, **kwargs|
          result = send(:"orig_#{method_name}", *args, **kwargs)
          return result if !SiteSetting.cdn_experiment_enabled
          CdnExperiment.perform_gsub(result, request.env)
        end
      end
    end

    ContentSecurityPolicy::Default.class_eval do
      alias_method :orig_script_assets, :script_assets
      def script_assets(*args, **kwargs)
        entries = orig_script_assets(*args, **kwargs)
        return entries if !SiteSetting.cdn_experiment_enabled
        additional_entries = []
        entries.each do |entry|
          if entry.include?(GlobalSetting.cdn_url)
            CdnExperiment.app_cdn_urls[1..].each { |cdn_url| additional_entries << entry.gsub(GlobalSetting.cdn_url, cdn_url) }
          elsif entry.include?(GlobalSetting.s3_cdn_url)
            CdnExperiment.s3_cdn_urls[1..].each { |s3_cdn_url| additional_entries << entry.gsub(GlobalSetting.s3_cdn_url, s3_cdn_url) }
          end
        end
        [*entries, *additional_entries]
      end
    end
  end
end
