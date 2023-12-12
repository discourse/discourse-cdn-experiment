# frozen_string_literal: true

describe "CDN Experiment" do
  before do
    global_setting :s3_cdn_url, "https://original-s3-cdn.example.com"
    global_setting :s3_bucket, "mybucket"
    global_setting :s3_region, "us-west-1"
    global_setting :s3_use_iam_profile, true

    set_cdn_url "https://original-app-cdn.example.com"

    SiteSetting.cdn_experiment_enabled = true
    SiteSetting.cdn_experiment_s3_cdns = "https://new-s3-cdn.example.com"
    SiteSetting.cdn_experiment_app_cdns = "https://new-app-cdn.example.com"
    Fabricate(:admin) # Stop the wizard from appearing
  end

  it "picks a random cdn based on ipv4 address" do
    get "/", env: { "REMOTE_ADDR" => "1.2.3.4" }
    doc = Nokogiri.HTML5(response.body)
    discourse_js = doc.at_css('head script[src*="discourse.js"]')
    expect(discourse_js["src"]).to match(/(original|new)-s3-cdn.example.com/)
  end

  it "picks a random cdn based on ipv6 address" do
    get "/", env: { "REMOTE_ADDR" => "1:2:3:4:5:6:7:8" }
    doc = Nokogiri.HTML5(response.body)
    discourse_js = doc.at_css('head script[src*="discourse.js"]')
    expect(discourse_js["src"]).to match(/(original|new)-s3-cdn.example.com/)
  end

  it "picks cdn based on index parameter" do
    get "/?_cdn_index=0"
    doc = Nokogiri.HTML5(response.body)
    discourse_js = doc.at_css('head script[src*="discourse.js"]')
    expect(discourse_js["src"]).to match(/original-s3-cdn.example.com/)

    get "/?_cdn_index=1"
    doc = Nokogiri.HTML5(response.body)
    discourse_js = doc.at_css('head script[src*="discourse.js"]')
    expect(discourse_js["src"]).to match(/new-s3-cdn.example.com/)
  end

  it "picks a random cdn based on ipv6 address" do
    get "/", env: { "REMOTE_ADDR" => "1:2:3:4:5:6:7:8" }
    doc = Nokogiri.HTML5(response.body)
    discourse_js = doc.at_css('head script[src*="discourse.js"]')
    expect(discourse_js["src"]).to match(/(original|new)-s3-cdn.example.com/)
  end

  context "with random generator stubbed" do
    before do
      CdnExperiment.stubs(:index_from_ip).returns(0, 1) # Sequential, not random
    end

    it "alternates CDNs for static JS assets" do
      get "/"
      expect(response.status).to eq(200)
      doc = Nokogiri.HTML5(response.body)
      discourse_js = doc.at_css('head script[src*="discourse.js"]')
      expect(discourse_js["src"]).to eq("https://original-s3-cdn.example.com/assets/discourse.js")

      get "/"
      expect(response.status).to eq(200)
      doc = Nokogiri.HTML5(response.body)
      discourse_js = doc.at_css('head script[src*="discourse.js"]')
      expect(discourse_js["src"]).to eq("https://new-s3-cdn.example.com/assets/discourse.js")
    end

    it "alternates CDNs for stylesheet assets" do
      get "/"
      expect(response.status).to eq(200)
      doc = Nokogiri.HTML5(response.body)
      desktop_css = doc.at_css('link[rel=stylesheet][href*="stylesheets/desktop"]')
      expect(desktop_css["href"]).to start_with(
        "https://original-app-cdn.example.com/stylesheets/desktop_",
      )

      get "/"
      expect(response.status).to eq(200)
      doc = Nokogiri.HTML5(response.body)
      desktop_css = doc.at_css('link[rel=stylesheet][href*="stylesheets/desktop"]')
      expect(desktop_css["href"]).to start_with(
        "https://new-app-cdn.example.com/stylesheets/desktop_",
      )
    end

    context "with theme JS" do
      before do
        t = Fabricate(:theme)
        t.set_field(
          target: :extra_js,
          type: :js,
          name: "discourse/initializers/blah.js",
          value: "console.log('hello world');",
        )
        t.save!
        t.set_default!
      end

      it "alternates CDNs for theme JS assets" do
        get "/"
        expect(response.status).to eq(200)
        doc = Nokogiri.HTML5(response.body)
        theme_js = doc.at_css('script[src*="/theme-javascripts/"]')
        expect(theme_js["src"]).to start_with(
          "https://original-app-cdn.example.com/theme-javascripts/",
        )

        get "/"
        expect(response.status).to eq(200)
        doc = Nokogiri.HTML5(response.body)
        theme_js = doc.at_css('script[src*="/theme-javascripts/"]')
        expect(theme_js["src"]).to start_with("https://new-app-cdn.example.com/theme-javascripts/")
      end
    end

    it "alternates CDNs in the setup data" do
      get "/"
      expect(response.status).to eq(200)
      doc = Nokogiri.HTML5(response.body)
      setup = doc.at_css("#data-discourse-setup")
      expect(setup["data-cdn"]).to eq("https://original-app-cdn.example.com")
      expect(setup["data-s3-cdn"]).to eq("https://original-s3-cdn.example.com")

      get "/"
      expect(response.status).to eq(200)
      doc = Nokogiri.HTML5(response.body)
      setup = doc.at_css("#data-discourse-setup")
      expect(setup["data-cdn"]).to eq("https://new-app-cdn.example.com")
      expect(setup["data-s3-cdn"]).to eq("https://new-s3-cdn.example.com")
    end

    it "includes all CDNs in the CSP" do
      get "/"
      expect(response.status).to eq(200)
      csp = response.headers["Content-Security-Policy"]
      expect(csp).to include("https://original-app-cdn.example.com")
      expect(csp).to include("https://new-app-cdn.example.com")
      expect(csp).to include("https://original-s3-cdn.example.com")
      expect(csp).to include("https://new-s3-cdn.example.com")
    end
  end
end
