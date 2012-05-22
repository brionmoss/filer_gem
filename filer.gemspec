Gem::Specification.new do |s|
  s.name        = 'filer'
  s.version     = '0.0.1'
  s.date        = '2012-05-19'
  s.summary     = "Manage your NetApp filer"
  s.description = "Interface with the OnTap API to manage volumes, snapmirrors, and more."
  s.authors     = ["Brion Moss"]
  s.email       = 'brion@ign.com'
  s.files       = [
    "lib/filer.rb",
    "lib/filer_aggr.rb",
    "lib/filer_exports.rb",
    "lib/filer_snap.rb",
    "lib/filer_vol.rb"
  ]
  s.executables = ["mkvol","snaplist"]                
  s.homepage    =
    'http://rubygems.org/gems/filer'
end