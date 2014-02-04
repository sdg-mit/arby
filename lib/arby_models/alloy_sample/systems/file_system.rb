require 'arby_models/alloy_sample/systems/__init'

module ArbyModels::AlloySample::Systems
  # =================================================================
  # Model of a generic file system
  #
  # @authors:       Eunsuk Kang
  # @translated_by: Aleksandar Milicevic
  # =================================================================
  alloy :FileSystem do
    abstract sig Object
    sig Name

    sig File extends Object {
      some(d: Dir) | in?(d.entries.contents)
    }

    sig Dir extends Object [
      entries: (set DirEntry),
      parent: (lone Dir)
    ] {
      parent == contents!.entries! and
      all(e1, e2: entries) { e1 == e2 if e1.name == e2.name } and
      this.not_in? this.^(Dir::parent) and
      if this != Root then Root.in? this.^(Dir::parent) end
    }

    one sig Root extends Dir { no parent }
    lone sig Curr extends Dir
    sig DirEntry [name: Name, contents: Object] { one entries! }

    # all directories besides root have one parent
    pred oneParent_buggyVersion {
      all(d: Dir - Root){ one d.parent }
    }

    # all directories besides root have one parent
    pred oneParent_correctVersion {
      all(d: Dir - Root) { one d.parent and one d.contents! }
    }

    # Only files may be linked (i.e., have more than one entry). That
    # is, all directories are the contents of at most one directory
    # entry.
    pred noDirAliases {
      all(o: Dir){ lone o.contents! }
    }

    check :buggy, 4   do noDirAliases if oneParent_buggyVersion end
    check :correct, 5 do noDirAliases if oneParent_correctVersion end

  end
end
