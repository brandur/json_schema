module JsonCommon
  module Node
    def pointer
      if parent
        parent.pointer + "/" + fragment
      else
        fragment
      end
    end
  end
end
