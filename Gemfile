source "https://rubygems.org"

# The 3GPP flavor now lives in the relaton monorepo, which absorbed the
# standalone relaton-3gpp gem. `Relaton::ThreeGpp::DataFetcher` writes the
# pubid-keyed index-v2; see crawler.rb for the index-v1 half.
gem "relaton", github: "relaton/relaton", branch: "main"

# relaton.gemspec pins pubid "~> 2.0.0.pre.alpha.8", but the 3GPP index needs
# pubid main: a bare reference must parse, and `parts` must default to [] on
# deserialization as well as on parse. Bundler reads a git dependency's
# gemspec, never its Gemfile, so relaton's own pin does not reach this bundle.
gem "pubid", git: "https://github.com/metanorma/pubid.git", branch: "main"

group :test do
  gem "rake"
  gem "rspec", "~> 3.13"
end
