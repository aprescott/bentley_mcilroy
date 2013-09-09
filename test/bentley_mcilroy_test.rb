require "test_helper"

describe BentleyMcIlroy::Codec do
  describe ".compress" do
    it "compresses strings" do
      codec = BentleyMcIlroy::Codec
      str = "aaaaaaaaaaaaaaaaaaaaaaa"
      
      (1..10).each { |i| codec.compress(str, i).should == [str[0, 1], [0, str.length-1]] }

      codec.compress("abcabcabc", 3).should == ["abc", [0, 6]]
      codec.compress("abababab", 2).should == ["ab", [0, 6]]
      codec.compress("abcdefabc", 3).should == ["abcdef", [0, 3]]
      codec.compress("abcdefabcdef", 3).should == ["abcdef", [0, 6]]
      codec.compress("abcabcabc", 2).should == ["abc", [0, 6]]
      codec.compress("xabcdabcdy", 2).should == ["xabcda", [2, 3], "y"]
      codec.compress("xabcdabcdy", 1).should == ["xabcd", [1, 4], "y"]
      codec.compress("xabcabcy", 2).should == ["xabca", [2, 2], "y"]
    end
    
    # "aaaa" should compress down to ["a", [0, 3]]
    it "picks the longest match on clashes"

    it "handles binary" do
      codec = BentleyMcIlroy::Codec
      str = ("\x52\303\x66" * 3)
      str.force_encoding("BINARY") if str.respond_to?(:force_encoding)

      codec.compress(str, 3).should == ["\x52\303\x66", [0, 6]]
    end
  end
  
  describe ".decompress" do
    it "converts arrays representing compressed strings into the full string" do
      codec = BentleyMcIlroy::Codec
      codec.decompress(["abc", [0, 6]]).should == "abcabcabc"
      codec.decompress(["abcdef", [0, 3]]).should == "abcdefabc"
      codec.decompress(["xabcda", [2, 3], "y"]).should == "xabcdabcdy"
      codec.decompress(["xabcd", [1, 4], "y"]).should == "xabcdabcdy"
      codec.decompress(["xabca", [2, 2], "y"]).should == "xabcabcy"
    end
    
    it "round-trips with the compression method" do
      codec = BentleyMcIlroy::Codec
      %w[aaaaaaaaa abcabcabcabc abababab abcdefabc abcdefabcdef abcabcabc xabcdabcdy xabcabcy].each do |s|
        (1..4).each do |n|
          codec.decompress(codec.compress(s, n)).should == s
        end
      end
    end
  end
  
  describe ".encode" do
    #                       11
    #         0123    45678901
    # encode("xaby", "abababab", 1) would be more efficiently encoded as
    #
    # ["x", [1, 2], [4, 6]]
    #
    # where [4, 6] refers to the decoded target itself, in the style of
    # VCDIFF. See RFC3284 section 3, where COPY 4, 4 + COPY 12, 24 is used.
    #
    # this should probably only be allowed with a flag or something.
    #
    # note that compress is more efficient for this type of input,
    # since the "source" is everything to the left of the current position:
    #
    # compress("abababab", 1) #=> ["ab", [0, 6]]
    it "can refer to its own target"

    it "encodes strings" do
      codec = BentleyMcIlroy::Codec
      codec.encode("abcdef", "defghiabc", 3).should == [[3, 3], "ghi", [0, 3]]
      codec.encode("abcdef", "defghiabc", 2).should == ["d", [4, 2], "ghi", [0, 3]]
      codec.encode("abcdef", "defghiabc", 1).should == [[3, 3], "ghi", [0, 3]]
      codec.encode("abc", "d", 3).should == ["d"]
      codec.encode("abc", "defghi", 3).should == ["defghi"]
      codec.encode("abcdef", "abcdef", 3).should == []
      codec.encode("abc", "abcdef", 3).should == [[0, 3], "def"]
      codec.encode("aaaaa", "aaaaaaaaaa", 3).should == [[0, 5], [0, 5]]
    end
  end
  
  describe ".decode" do
    it "applies the given delta to the given source" do
      codec = BentleyMcIlroy::Codec
      codec.decode("aaaaa", [[0, 5], [0, 5]]).should == "aaaaaaaaaa"
      codec.decode("abcdef", [[3, 3], "ghi", [0, 3]]).should == "defghiabc"
    end
    
    it "round-trips with the delta method" do
      codec = BentleyMcIlroy::Codec
      (1..4).each do |n|
        codec.decode("abcdef", codec.encode("abcdef", "defghiabc", n)).should == "defghiabc"
      end
    end
  end
end

