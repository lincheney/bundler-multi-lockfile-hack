require 'spec_helper'

def read_lockfile(path)
  Bundler::LockfileParser.new(Bundler.read_file(path))
end

def bundle(cmd)
  version = "_#{ENV['BUNDLER_VERSION']}_" if ENV['BUNDLER_VERSION']
  cmd = "bundle #{version} #{cmd}"
  system(cmd)
end

lockfiles = {
  "doc.lock" => %w{ rdoc sdoc },
  "doc.test.lock" => %w{ rdoc sdoc rspec rspec-rails shoulda-matchers codeclimate-test-reporter },
  "other.lock" => %w{ json activesupport maruku },
  "rails.test.lock" => %w{ rspec-rails shoulda-matchers codeclimate-test-reporter },
}

git_sources = {
  'codeclimate-test-reporter' => 'ruby-test-reporter',
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
      expect(gemfile_lock.sources).to include(*lockfile.sources)
    end

    it "#{file} should have a subset of Gemfile.lock's specs" do
      lockfile = read_lockfile(file)
      expect(gemfile_lock.specs).to include(*lockfile.specs)
    end

    it "#{file} should have only the correct dependencies" do
      lockfile = read_lockfile(file)
      expect(lockfile.dependencies.map(&:name)).to match_array(deps)
    end

    describe 'sources' do
      it "#{file} should have only the correct git sources" do
        lockfile = read_lockfile(file)
        sources = lockfile.sources.select{|s| s.is_a? Bundler::Source::Git}
        expected_sources = deps.map{|d| git_sources[d]}.compact
        expect(sources.map(&:name)).to match_array(expected_sources)
      end
    end
  end
end

describe 'multi lockfile hack' do
  let(:gemfile_lock)  { read_lockfile('Gemfile.lock') }

  describe 'install' do
    context 'with no Gemfile.lock' do
      before(:all) do
        Dir.chdir(File.expand_path('install', __dir__))
        FileUtils.rm(Dir.glob('*.lock'))
        bundle('install')
      end

      it_behaves_like 'a lockfile writer'
    end

    context 'with an existing Gemfile.lock' do
      before(:all) do
        Dir.chdir(File.expand_path('install-with-lock', __dir__))
        FileUtils.rm(Dir.glob('*.lock'))
        FileUtils.cp('Gemfile.lock.backup', 'Gemfile.lock')
        bundle('install')
      end

      it 'should not need to update Gemfile.lock' do
        expect(File.read('Gemfile.lock')).to eql File.read('Gemfile.lock.backup')
      end

      it_behaves_like 'a lockfile writer'
    end
  end

  describe 'update' do
    context 'with no Gemfile.lock' do
      before(:all) do
        Dir.chdir(File.expand_path('install', __dir__))
        FileUtils.rm(Dir.glob('*.lock'))
        bundle('update')
      end

      it_behaves_like 'a lockfile writer'
    end

    context 'with an existing Gemfile.lock' do
      before(:all) do
        Dir.chdir(File.expand_path('install-with-lock', __dir__))
        FileUtils.rm(Dir.glob('*.lock'))
        FileUtils.cp('Gemfile.lock.backup', 'Gemfile.lock')
        bundle('update')
      end

      it 'should have updated Gemfile.lock' do
        expect(File.read('Gemfile.lock')).to_not eql File.read('Gemfile.lock.backup')
      end

      it_behaves_like 'a lockfile writer'
    end

    context 'updating a single gem' do
      before(:all) do
        Dir.chdir(File.expand_path('install-with-lock', __dir__))
        FileUtils.rm(Dir.glob('*.lock'))
        FileUtils.cp('Gemfile.lock.backup', 'Gemfile.lock')
        bundle('update sqlite3')
      end

      it 'should have updated Gemfile.lock' do
        expect(File.read('Gemfile.lock')).to_not eql File.read('Gemfile.lock.backup')
      end

      it_behaves_like 'a lockfile writer'
    end
  end

end
