# Configure Zeitwerk to properly load domains
Rails.autoloaders.main.collapse("#{Rails.root}/app/domains/**/models")
Rails.autoloaders.main.collapse("#{Rails.root}/app/domains/**/controllers")
Rails.autoloaders.main.collapse("#{Rails.root}/app/domains/**/services")
Rails.autoloaders.main.collapse("#{Rails.root}/app/domains/**/repositories")
