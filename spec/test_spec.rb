require 'spec_helper'
require 'securerandom'
require 'fileutils'
require 'bundler'
p Bundler

def read_lockfile(path)
  Bundler::LockfileParser.new(Bundler.read_file(path))
end

def bundle(cmd)
  version = "_#{ENV['BUNDLER_VERSION']}_" if ENV['BUNDLER_VERSION']

  unset_env = ENV.select{|k| /BUNDLE|RUBY/ =~ k}
  unset_env.each_key{|k| unset_env[k] = nil}

  cmd = "bundle #{version} #{cmd} "
  puts "Running #{cmd}..."
  system(unset_env, cmd)
end

# try to load bundler first
exit(1) unless bundle('--version')

lockfiles = {
  'doc.lock' => %w{ rdoc sdoc },
  'doc.test.lock' => %w{ rdoc sdoc rspec rspec-rails shoulda-matchers codeclimate-test-reporter },
  'other.lock' => %w{ json activesupport maruku rbench },
  'rails.test.lock' => %w{ rspec-rails shoulda-matchers codeclimate-test-reporter },
  'git_only.lock' => %w{ mime-types multi_json colorize },
}

git_sources = {
  'dock.lock' => %w{ },
  'doc.test.lock' => %w{ ruby-test-reporter simplecov },
  'other.lock' => %w{ },
  'rails.test.lock' => %w{ ruby-test-reporter simplecov },
  'git_only.lock' => %w{ ruby-mime-types multi_json colorize },
}

path_sources = {
  'rbench' => 'rbench-gem',
}

shared_examples 'a lockfile writer' do
  lockfiles.each do |file, deps|
    it "#{file} should have a subset of Gemfile.lock's platforms" do
      lockfile = read_lockfile(file)
      expect(gemfile_lock.platforms).to include(*lockfile.platforms)
    end

    it "#{file} should have a subset of Gemfile.lock's dependencies" do
      lockfile = read_lockfile(file)
      expect(gemfile_lock.dependencies).to include(*lockfile.dependencies)
    end

    it "#{file} should have a subset of Gemfile.lock's sources" do
      lockfile = read_lockfile(file)
      sources = lockfile.sources
      sources = sources.reject{|src| src.is_a?(Bundler::Source::Rubygems)} if file == 'git_only.lock'
      expect(gemfile_lock.sources).to include(*sources)
    end

    if file == 'git_only.lock'
      it "#{file} should have a subset of Gemfile.lock's rubygems sources" do
        lockfile = read_lockfile(file)

        git_only = lockfile.sources.select{|src| src.is_a?(Bundler::Source::Rubygems)}
        gemfile = gemfile_lock.sources.select{|src| src.is_a?(Bundler::Source::Rubygems)}

        git_only.each do |src|
          expect( gemfile.any?{|s| (src.remotes - s.remotes).empty? } ).to be_truthy
        end
      end
    end

    it "#{file} should have a subset of Gemfile.lock's specs" do
      lockfile = read_lockfile(file)
      expect(gemfile_lock.specs).to include(*lockfile.specs)
    end

    it "#{file} should have all the required specs" do
      lockfile = read_lockfile(file)
      lockfile.specs.each do |spec|
        expect(lockfile.specs.map(&:name)).to include(*spec.dependencies.map(&:name))
      end
    end

    it "#{file} should have only the correct dependencies" do
      lockfile = read_lockfile(file)
      expect(lockfile.dependencies.map(&:name)).to match_array(deps)
    end

    describe 'sources' do
      it "#{file} should have only the correct git sources" do
        lockfile = read_lockfile(file)
        sources = lockfile.sources.select{|s| s.instance_of? Bundler::Source::Git}
        expected_sources = git_sources[file]
        expect(sources.map(&:name)).to match_array(expected_sources)
      end

      it "#{file} should have only the correct path sources" do
        lockfile = read_lockfile(file)
#         use instance of, since Source::Git < Source::Path
        sources = lockfile.sources.select{|s| s.instance_of? Bundler::Source::Path}
        expected_sources = deps.map{|d| path_sources[d]}.compact
        expect(sources.map(&:name)).to match_array(expected_sources)
      end
    end

  end
end

describe 'multi lockfile hack' do
  def compare_lockfiles(a, b, equal=true)
    files = [a, b].map{|file| File.read(file).strip.split("\n\n")}
    # ignore the BUNDLED WITH header that comes with pre releases
    files = files.map{|file| file.reject{|chunk| chunk.start_with?("BUNDLED WITH\n")} }
    if equal
      expect(files[0]).to match_array(files[1])
    else
      expect(files[0]).to_not match_array(files[1])
    end
  end

  let(:gemfile_lock)  { read_lockfile('Gemfile.lock') }

  before(:all) do
    Dir.chdir(File.expand_path('test-dir', File.dirname(__FILE__)))
    FileUtils.rm(Dir.glob('*.lock'))
  end

  describe 'install' do
    context 'with no Gemfile.lock' do
      before(:all) do
        bundle('install')
      end

      it_behaves_like 'a lockfile writer'
    end

    context 'with an existing Gemfile.lock' do
      before(:all) do
        FileUtils.cp('Gemfile.lock.backup', 'Gemfile.lock')
        bundle('install')
      end

      it 'should not need to update Gemfile.lock' do
        compare_lockfiles('Gemfile.lock', 'Gemfile.lock.backup', equal=true)
      end

      it_behaves_like 'a lockfile writer'
    end

    context 'with existing lock files' do
      before(:all) do
        FileUtils.cp('Gemfile.lock.backup', 'Gemfile.lock')
        # write some gibberish to the lock files
        lockfiles.each_key{|file| File.write(file, 10.times.map{SecureRandom.hex}.join) }
        bundle('install')
      end

      # it should completely ignore them
      it_behaves_like 'a lockfile writer'
    end
  end

  describe 'update' do
    context 'with no Gemfile.lock' do
      before(:all) do
        bundle('update')
      end

      it_behaves_like 'a lockfile writer'
    end

    context 'with an existing Gemfile.lock' do
      before(:all) do
        FileUtils.cp('Gemfile.lock.backup', 'Gemfile.lock')
        bundle('update')
      end

      it 'should have updated Gemfile.lock' do
        compare_lockfiles('Gemfile.lock', 'Gemfile.lock.backup', equal=false)
      end

      it_behaves_like 'a lockfile writer'
    end

    context 'updating a single gem' do
      before(:all) do
        FileUtils.cp('Gemfile.lock.backup', 'Gemfile.lock')
        bundle('update sqlite3')
      end

      it 'should have updated Gemfile.lock' do
        compare_lockfiles('Gemfile.lock', 'Gemfile.lock.backup', equal=false)
      end

      it_behaves_like 'a lockfile writer'
    end
  end

end
