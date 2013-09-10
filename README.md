[![Build Status](https://travis-ci.org/aprescott/bentley_mcilroy.png?branch=master)](https://travis-ci.org/aprescott/bentley_mcilroy)

A Ruby implementation of Bentley-McIlroy's data compression scheme to encode
compressed versions of strings, and compute deltas between source and target.

Note the compression and delta encodings are simply represented with Ruby
objects, and is independent of any particular binary format.

The fingerprinting algorithm is the rolling hash frequently used for Rabin-Karp
string matching.

# Usage

To compress a string, pass the input and block size.

    codec = BentleyMcIlroy::Codec
    codec.compress("aaaaaa", 3)     #=> ["a", [0, 5]]
    codec.compress("abcabcabc", 3)  #=> ["abc", [0, 6]]
    codec.compress("xabcdabcdy", 2) #=> ["xabcda", [2, 3], "y"]
    codec.compress("xabcdabcdy", 1) #=> ["xabcd", [1, 4], "y"]

# Modes of operation

This library supports two modes of operation: compression and delta encoding.
With compression, a single input is compressed. With delta encoding, there is a
(non-empty) source and a target, and the result is a delta which can be
used to reconstruct the target, given the source. Compression is a special
case of delta encoding where there is no source.

With compression, the source data is everything to the left of the position we've
reached along the string. With delta encoding, the source data is fixed for the
entire time we move left-to-right through the target string.

Compression:

    codec.compress("aaaaaa", 3)     #=> ["a", [0, 5]]
    codec.compress("abcabcabc", 3)  #=> ["abc", [0, 6]]
    codec.compress("xabcdabcdy", 2) #=> ["xabcda", [2, 3], "y"]
    codec.compress("xabcdabcdy", 1) #=> ["xabcd", [1, 4], "y"]

Delta encoding is similar:

    codec.encode("abcd", "xabcdyabcdz", 1) #=> ["x", [0, 4], "y", [0, 4], "z"]
    codec.encode("xyz", "xyz", 3) #=> []

To decompress:

    codec.decompress(["xabcd", [1, 4], "y"]) #=> "xabcdabcdy"

To decode a delta against a source:

    codec.decode("abcd", ["x", [0, 4], "y", [0, 4], "z"]) #=> "xabcdyabcdz"

# About Bentley-McIlroy

The Bentley-McIlroy compression scheme is an algorithm for compressing a
string by finding long common substrings. The algorithm and its properties
are described in greater detail in their [1999 paper][bentley-mcilroy paper]. The technique, with a
source dictionary and a target string, is used in Google's implementation of
a VCDIFF encoder, [open-vcdiff][open-vcdiff project], as part of encoding deltas.

[bentley-mcilroy paper]: http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.11.8470&rep=rep1&type=pdf
[open-vcdiff project]: http://code.google.com/p/open-vcdiff/

To give a brief summary, the algorithm works by fixing a window of block size
b and then sliding over the string, storing the fingerprint of every b-th
window.  These stored fingerprints are then used to detect repetitions later
on in the string.

The algorithm in pseudocode, as given in the paper is:

    initialize fp
    for (i = b; i < n; i++)
      if (i % b == 0)
        store(fp, i)
      update fp to include a[i] and exclude a[i-b]
      checkformatch(fp, i)

In the algorithm above, `checkformatch(fp, i)` looks up the fingerprint `fp` in a
hash table and then encodes a match if one is found.

`checkformatch(fp, i)` is the core piece of this algorithm, and "encodes a
match" is not fully described in the paper. The rest of the algorithm simply
describes moving through the string with a sliding window, looking at
substrings and storing fingerprints whenever we cross a block boundary.

As described in the paper, suppose b = 100 and that the current block matches
block 56 (i.e., bytes 5600 through to 5699). This current block could then be
encoded as <5600,100>.

There are two similar improvements which can be made, so as to prevent
`"ababab"` from compressing into `"ab<0,2><0,2>"`, both of which are also in the
paper.  When we know that the current block matches block 56, we can extend
the match as far back as possible, not exceeding b - 1 bytes. Similarly, we
can move the match far forward as possible without limitation.

The reason there is a limit of b-1 bytes when moving backwards is that if
there were more to match beyond b-1 bytes, it would've been found in a
previous iteration of the loop.

This library implementation moves matches forward, but does not move matches
backwards.

To be more explicit about what extending the match means, consider

    xabcdabcdy  (the string)
    0123456789  (indices)

with a block size of b = 2. Moving left to right, the fingerprints of `"xa"`,
`"ab"`, `"bc"`, ..., are computed, but only `"xa"`, `"bc"`, `"da"`, ... are stored. When
`"ab"` is seen at `5..6`, there is no corresponding entry in the hash table, so
nothing is done, yet. On the next substring of length 2, `"bc"`, at positions
`6..7`, there _is_ a corresponding entry in the hash table, so there's a match,
which we could encode as `<2, 2>`, say. However, we'd like to _actually_ produce
`<1, 4>`, which is more efficient. So starting with `<2, 2>`, we move the match
back 1 character for both the `"bc"` at `6..7` and the `"bc"` at `2..3`, then check
if `1..3` matches `5..7`, which it does. This is moving the match backwards.

For moving the match forwards, simply do the same thing. Check if `1..4` matches
`6..8`, which it does. `1..5` does not match `6..9`, so we use `<1, 4>` and we're done.

The resulting string, with backward- and forward-extension is `xabcd<1, 4>y`. In
the case of no backward extensions, it is `xabcda<2, 3>y`.

# License

Copyright (c) Adam Prescott, released under the MIT license. See the license file.
