require "test_helper"

describe RollingHash do
  describe "#hash(input)" do
    it "hashes the input using a polynomial" do
      hasher = RollingHash.new
      hasher.hash("abc").should == 6432038
      hasher.hash("bcd").should == 6498345
    end
  end

  describe "#next_hash(next_input)" do
    it "takes the previously hash, the given next input and computes the new hash" do
      hasher = RollingHash.new
      h = hasher.hash("abc")
      new_h = hasher.next_hash("d")
      new_h.should == RollingHash.new.hash("bcd")
    end
  end
end
