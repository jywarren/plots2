#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

Plots2::Application.load_tasks

Rake::Task['test:run'].clear
Rake::Task['test:all'].clear

namespace :test do

  # run normal rails tests but not solr tests
  #Rake::TestTask.new(:_run) do |t|
  Rake::TestTask.new(:run) do |t|
    t.libs << "test"
    t.test_files = FileList['test/**/*_test.rb'].exclude(
      'test/solr/**/*_test.rb'
    )
  end
  #task :run => ['test:_run']

  # rake test:all
  desc "Run rails and jasmine tests"
  task :all => :environment do
    require 'coveralls/rake/task'
    Coveralls::RakeTask.new
    if ENV['GENERATE_REPORT'] == 'true'
      require 'ci/reporter/rake/test_unit'
      Rake::Task["ci:setup:testunit"].execute
    end
    puts "Running Rails tests"
    Rake::Task["test:run"].execute
    puts "Preparing Solr-dependent tests"
    Rake::Task["test:solr_setup"].execute
    Rake::Task["test:solr"].execute
    Rake::Task["test:solr_cleanup"].execute
    puts "Running jasmine tests headlessly"
    Rake::Task["spec:javascript"].execute
    Rake::Task["coveralls:push"].execute
  end

  desc "Run rails and jasmine tests"
  task :javascript do
    puts "Running jasmine tests headlessly"
    Rake::Task["spec:javascript"].execute
  end

  desc "Prepare for Solr-specific tests"
  # Solr is assumed running from the container or otherwise available as in sunspot.yml.
  task :solr_setup do
    # overwrite "diabled" in test for sunspot.yml
    require 'yaml'
    sunspot = YAML::load_file "config/sunspot.yml"
    sunspot['test']['disabled'] = false
    File.open("config/sunspot.yml", "w") do |file|
      file.write sunspot.to_yaml
    end
    puts "turning on solr dependence at config/sunspot.yml"
    puts sunspot.to_yaml
    `RAILS_ENV=test rake SOLR_DISABLE_CHECK=1 sunspot:reindex`
  end

  desc "Clean up after solr-specific tests"
  task :solr_cleanup do
    # restore "diabled" to true in test for sunspot.yml
    puts "turning solr dependence back off in tests at config/sunspot.yml"
    require 'yaml'
    sunspot = YAML::load_file "config/sunspot.yml"
    sunspot['test']['disabled'] = true
    File.open("config/sunspot.yml", "w") do |file|
      file.write sunspot.to_yaml
    end
  end

  desc "Run Solr-specific tests"
  Rake::TestTask.new(:solr) do |t|
    puts "Running Solr-dependent tests"
    t.libs << "test"
    t.pattern = 'test/solr/*_test.rb'
    t.verbose = true
  end

end
