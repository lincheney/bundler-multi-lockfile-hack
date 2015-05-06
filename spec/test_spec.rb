require 'spec_helper'

def read_lockfile(path)
  Bundler::LockfileParser.new(Bundler.read_file(path))
end

lockfiles = {
  "doc.lock" => %w{ rdoc sdoc },
  "doc.test.lock" => %w{ rdoc sdoc rspec rspec-rails shoulda-matchers codeclimate-test-reporter },
  "other.lock" => %w{ json activesupport maruku },
  "rails.test.lock" => %w{ rspec-rails shoulda-matchers codeclimate-test-reporter },
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

    it "#{file} should have a subset of Gemfile.lock's specs" do
      lockfile = read_lockfile(file)
      expect(gemfile_lock.specs).to include(*lockfile.specs)
    end

    it "#{file} should have all the correct dependencies" do
      lockfile = read_lockfile(file)
      expect(lockfile.dependencies.map(&:name)).to match_array(deps)
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
        system "bundle install"
      end

      it_behaves_like 'a lockfile writer'
    end
  end
end
