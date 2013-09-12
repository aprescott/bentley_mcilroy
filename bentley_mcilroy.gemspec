Gem::Specification.new do |s|
  s.name         = "bentley_mcilroy"
  s.version      = "0.0.2"
  s.authors      = ["Adam Prescott"]
  s.email        = ["adam@aprescott.com"]
  s.homepage     = "https://github.com/aprescott/bentley_mcilroy"
  s.summary      = "Bentley-McIlroy compression scheme implementation in Ruby."
  s.description  = "A compression scheme using the Bentley-McIlroy data compression technique of finding long common substrings."
  s.files        = Dir["{lib/**/*,test/**/*}"] + %w[LICENSE README.md bentley_mcilroy.gemspec rakefile]
  s.test_files   = Dir["test/*"]
  s.require_path = "lib"
  s.license      = "MIT"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
end
