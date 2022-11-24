## CDN Experiment

Allows multiple CDNs to be specified (e.g. for A/B(/C...) performance tests). Users will be served assets from a random CDN
calculated using a function of their IP address (i.e. a given user will see a consistent set of CDNs). In combination with
the [discourse-client-performance](https://github.com/discourse/discourse-client-performance) plugin, this can be used to
measure differences in CDN performance.

This plugin is designed for use on Discourse environments with both an 's3 cdn' and an 'app cdns'. Using this plugin in other
environments is untested and may lead to unexpected behaviour.

You must specify an equal number of S3 CDNs and App CDNs. CDNs will always be handed out in pairs (i.e. if the second S3 CDN is
used, the second App CDN will also be used).

### Configuration

The plugin is disabled-by-default. It is configured using site settings (which, as normal, can be overridden for an entire cluster using
environment variables).

- **cdn experiment enabled** (`DISCOURSE_CDN_EXPERIMENT_ENABLED`) (default `false`): Set 'true' to enable the plugin.

- **cdn experiment s3 cdns** (`DISCOURSE_CDN_S3_CDNS`) (default empty): Pipe-separated additional S3 CDN domains. Include protocol. No trailing slash.

- **cdn experiment app cdns** (`DISCOURSE_CDN_APP_CDNS`) (default empty): Pipe-separated additional App CDN domains. Include protocol. No trailing slash.

The CDNs configured via the Discourse core settings are always included in the experiment - you do not need to add them to this plugin's configuration.
