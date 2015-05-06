module Bundler::MultiLockfileHack

  Locks = Struct.new(:gemfile, :groups, :lockfile)

  def self.lockfiles; @lockfiles ||= {}; end

  def to_definition(lockfile, unlock)
    super
    DefinitionHack.new(lockfile, @dependencies, @sources, unlock, @ruby_version)
  end

  def generate_lockfile(lockfile: nil, gemfile: nil, groups: nil)
    raise 'Expected one of gemfile or groups' unless gemfile or groups

    groups &&= Array(groups)
    lockfile ||= [gemfile, groups, 'lock'].flatten.compact.join('.')
    Bundler::MultiLockfileHack.lockfiles[lockfile] = Locks.new(gemfile, groups, lockfile)
  end

  class DefinitionHack < Bundler::Definition
    def lock(filename)
      result = super(filename)
      master = Bundler::LockfileParser.new(Bundler.read_file(filename))
      Bundler::MultiLockfileHack.lockfiles.values.each{|data| _write_lock(data, master)}
      result
    end

    def _write_lock(data, master)
      if data.gemfile
        deps = Bundler::Dsl.new.eval_gemfile(data.gemfile)
      else
        deps = @dependencies
      end

      deps = deps.select{|d| (d.groups & data.groups).any?} if data.groups
      sources = SourceListHack.new(@sources, deps.map(&:name))
      @sources.git_sources.each{|git| git.instance_eval{@git_proxy = nil} }

      DefinitionHack2.new(data.lockfile, deps, sources, @unlock, @ruby_version).lock(data.lockfile)
    end
  end

  class SourceListHack < Bundler::SourceList
    def initialize(src, names)
      super()
      filter = proc{|src| (src.specs.map(&:name) & names).any?}
      @path_sources = src.path_sources.select(&filter)
      @git_sources = src.git_sources.select(&filter)
      @rubygems_sources = (src.rubygems_sources - [@rubygems_aggregate]).select(&filter)
    end
  end

  class DefinitionHack2 < Bundler::Definition
    def resolve
      super.select{|spec| @dependencies.map(&:name).include? spec.name}
    end
  end

end
