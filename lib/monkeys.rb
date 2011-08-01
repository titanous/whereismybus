class Struct
  def to_json(state = nil)
    hash = {}
    each_pair { |name, value| hash[name] = value }
    hash.to_json(state)
  end
end
