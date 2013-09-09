require "rolling_hash"

module BentleyMcIlroy
# A fixed block of text, appearing in the original text at one of
# 0..b-1, b..2b-1, 2b..3b-1, ...
class Block
  attr_reader :text, :position

  def initialize(text, position)
    @text = text
    @position = position
  end

  def hash
    RollingHash.new.hash(text)
  end
end

# A container for the original text we're processing. Divides the text into
# Block objects.
class BlockSequencedText
  attr_reader :blocks, :text

  def initialize(text, block_size)
    @text = text
    @block_size = block_size
    @blocks = []

    # "onetwothree" -> ["one", "two", "thr", "ee"]
    @text.scan(/.(?:.?){#{@block_size-1}}/).each.with_index do |text_block, index|
      @blocks << Block.new(text_block, index * @block_size)
    end
  end
end

# Look-up table with a #find method which finds an appropriate block and then
# modifies the match to extend it to more characters.
class BlockFingerprintTable
  def initialize(block_sequenced_text)
    @blocked_text = block_sequenced_text
    @hash = {}

    @blocked_text.blocks.each do |block|
      (@hash[block.hash] ||= []) << block
    end
  end

  def find_for_compress(fingerprint, block_size, target, position)
    source = @blocked_text.text
    find(fingerprint, block_size, source, target, position)
  end

  def find_for_diff(fingerprint, block_size, target)
    source = @blocked_text.text
    find(fingerprint, block_size, source, target)
  end

  private
  
  def find(fingerprint, block_size, source, target, position = nil)
    blocks = @hash[fingerprint]
    return nil unless blocks
    
    blocks.each do |block|
      next unless block.text == target[0, block_size]
      
      # in compression, since we don't have true source and target strings as
      # separate things, we have to ensure that we don't use a fingerprinted
      # block which appears _after_ the current position, otherwise
      #
      # a<x, 0> with x > 0
      #
      # might happen, or similar. since blocks are ordered left to right in the
      # string, we can just return nil, because we know there's not going to be
      # a valid block for compression.
      if position && block.position >= position
        return nil
      end
      
      # we know that block matches, so cut it from the beginning,
      # so we can then see how much of the rest also matches
      source_match = source[block.position + block_size..-1]
      target_match = target[block_size..-1]
      
      # in a backwards extension, we can see how many of the characters before
      # +position+ (up the previous block we covered, which is +limit+) match
      # characters block.position (up to b-1) characters. In other words, we can
      # find the maximum i such that
      #
      # original_text[position-k, 1] == original_text[block.position-k, 1]
      #
      # for all k in {1, 2, ..., i}, where i <= b-1

      # it may be that the block we've matched on reaches to the end of the
      # string, in which case, bail
      if source_match.empty? || target_match.empty?
        return block
      end

      end_index = find_end_index(source_match, target_match)
      match = produce_match(end_index, block, source)
      return match
    end

    nil
  end
  
  def find_end_index(source, target)
    end_index = 0
    any_match = false
    while end_index < source.length && end_index < target.length && source[end_index, 1] == target[end_index, 1]
      any_match = true
      end_index += 1
    end
    # undo the final increment, since that's where it failed the equality check
    end_index -= 1
    
    any_match ? end_index : nil
  end

  def produce_match(end_index, block, source)
    text = block.text
    if end_index # we have more to grab in the string
      text += source[0..end_index]
    end
    Block.new(text, block.position)
  end
end

class Codec
  def self.decompress(sequence)
    sequence.inject("") do |result, i|
      if i.is_a?(Array)
        index, length = i
        length.times do |k|
          result << result[index+k, 1]
        end
        result
      else
        result << i
      end
    end
  end
  
  def self.decode(source, delta)
    delta.inject("") do |result, i|
      if i.is_a?(Array)
        index, length = i
        result << source[index, length]
      else
        result << i
      end
    end
  end

  def self.compress(text, block_size)
    __compress_encode__(text, nil, block_size)
  end

  def self.encode(source, target, block_size)
    __compress_encode__(source, target, block_size)
  end

  private
  
  def self.__compress_encode__(source, target, block_size)
    return [] if source == target
    
    block_sequenced_text = BlockSequencedText.new(source, block_size)
    table = BlockFingerprintTable.new(block_sequenced_text)
    output = []
    buffer = ""
    current_hash = nil
    hasher = RollingHash.new
    
    mode = (target ? :diff : :compress)
    
    if mode == :compress
      # it's the source we're compressing, there is no target
      text = source
    else
      # it's the target we're compressing against the source
      text = target
    end

    position = 0
    while position < text.length

      if text.length - position < block_size
        # if there isn't a block-sized substring in the remaining text, stop.
        # note that we could add the buffer to the output here, but if block_size
        # is 1, text.length - position < 1 can't be true, so the final character
        # would go missing. so appending to the buffer goes below, outside the
        # while loop.
        break
      end

      # if we've recently found a block of text which matches and added that to
      # the output, current_hash will be reset to nil, so get the new hash. note
      # that we can't just use next_hash, because we might have skipped several
      # characters in one go, which breaks the rolling aspect of the hash
      if !current_hash
        current_hash = hasher.hash(text[position, block_size])
      else
        # position-1 is the previous position, + block_size to get the last
        # character of the current block
        current_hash = hasher.next_hash(text[position-1 + block_size, 1])
      end

      match = target ? table.find_for_diff(current_hash, block_size, target[position..-1]) :
                       table.find_for_compress(current_hash, block_size, text[position..-1], position)

      if match
        if !buffer.empty?
          output << buffer
          buffer = ""
        end

        output << [match.position, match.text.length]
        position += match.text.length
        current_hash = nil
        # get a new hasher, because we've skipped over by match.text.length
        # characters, so the rolling hash's next_hash won't work
        hasher = RollingHash.new
      else
        buffer << text[position, 1]
        position += 1
      end
    end

    remainder = buffer + text[position..-1]
    output << remainder if !remainder.empty?
    output
  end
end
end
