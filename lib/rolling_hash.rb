if RUBY_VERSION < "1.9"
  class String
    def ord
      self[0]
    end
  end
end

# Rolling hash as used in Rabin-Karp.
#
# hasher = RollingHash.new
# hasher.hash("abc")    #=> 6432038
# hasher.next_hash("d") #=> 6498345
#                             ||
# hasher.hash("bcd")    #=> 6498345
class RollingHash
  def initialize(hash = {})
    hash = { :base => 257, # prime
             :mod  => 1000000007
           }.merge!(hash)
    @base = hash[:base]
    @mod  = hash[:mod]
  end
  
  # Compute @base**power working modulo @mod
  def modulo_exp(power)
    self.class.modulo_exp(@base, power, @mod)
  end
  
  # Given a string "abc...xyz" with length len,
  # return the hash using @base as
  # 
  # "a".ord * @base**(len - 1) +
  # "b".ord * @base**(len - 2) +
  # ... +
  # "y".ord * @base**(1) +
  # "z".ord * @base**0 (== "z".ord)
  def hash(input)
    hash = 0
    characters = input.split("")
    input_length = characters.length
    
    characters.each_with_index do |character, index|
      hash += character.ord * modulo_exp(input_length - 1 - index) % @mod
      hash = hash % @mod
    end
    @prev_hash = hash
    @prev_input = input
    @highest_power = input_length - 1
    hash
  end
  
  # Returns the hash of (@prev_input[1..-1] + character)
  # by using @prev_hash, so that the sum turns from
  # 
  # "a".ord       * @base**(len - 1) +
  # "b".ord       * @base**(len - 2) +
  # ... +
  # "y".ord       * @base**(1) +
  # "z".ord       * @base**0 (== "z".ord)
  # 
  # into
  # 
  # "b".ord       * @base**(len - 1) +
  # ... +
  # "y".ord       * @base**(2) +
  # "z".ord       * @base**1 +
  # character.ord * @base**0
  def next_hash(character)
    # the leading value of the computed sum
    char_to_subtract = @prev_input.chars.first
    hash = @prev_hash
    
    # subtract the leading value
    hash = hash - char_to_subtract.ord * @base**@highest_power
    
    # shift everything over to the left by 1, and add the
    # new character as the lowest value
    hash = (hash * @base) + character.ord
    hash = hash % @mod
    
    # trim off the first character
    @prev_input.slice!(0)
    @prev_input << character
    @prev_hash = hash
    
    hash
  end
  
  private
  
  # Returns n**power but reduced modulo mod
  # at each step of the calculation.
  def self.modulo_exp(n, power, mod)
    value = 1
    power.times do
      value = (n * value) % mod
    end
    value
  end
end
