{- Acknowledgements
~~~~~~~~~~~~~~~~~~~

* 'prefixF', 'suffixF', 'padBothF', 'groupInt' are taken from
      <https://hackage.haskell.org/package/formatting>
  Written by Github user @mwm
      <https://github.com/mwm>

* 'ordinalF' is taken from
      <https://hackage.haskell.org/package/formatting>
  Written by Chris Done
      <https://github.com/chrisdone>

* 'atBase' is taken from
      <https://hackage.haskell.org/package/formatting>, originally from
      <https://hackage.haskell.org/package/lens>
  Seems to be written by Johan Kiviniemi
      <https://github.com/ion1>
-}

{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE CPP #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

#include "overlap.h"

module Fmt
(
  -- * Overloaded strings
  -- $overloadedstrings

  -- * Examples
  -- $examples

  -- * Migration guide from @formatting@
  -- $migration

  -- * Basic formatting
  -- $brackets

  -- ** Ordinary brackets
  -- $god1
  (+|),
  (|+),
  -- ** 'Show' brackets
  -- $god2
  (+||),
  (||+),
  -- ** Combinations
  -- $god3
  (|++|),
  (||++||),
  (|++||),
  (||++|),

  -- * Old-style formatting
  format,
  formatLn,
  Format,

  -- * Helper functions
  fmt,
  fmtLn,

  Builder,
  Buildable(..),

  -- * Formatters

  -- ** Time
  module Fmt.Time,

  -- ** Text
  indentF, indentF',
  nameF,
  unwordsF,
  unlinesF,

  -- ** Lists
  listF, listF',
  blockListF, blockListF',
  jsonListF, jsonListF',

  -- ** Maps
  mapF, mapF',
  blockMapF, blockMapF',
  jsonMapF, jsonMapF',

  -- ** Tuples
  tupleF,

  -- ** ADTs
  maybeF,
  eitherF,

  -- ** Padding/trimming
  prefixF,
  suffixF,
  padLeftF,
  padRightF,
  padBothF,

  -- ** Hex
  hexF,

  -- ** Bytestrings
  base64F,
  base64UrlF,

  -- ** Integers
  ordinalF,
  commaizeF,
  -- *** Base conversion
  octF,
  binF,
  baseF,

  -- ** Floating-point
  floatF,
  exptF,
  fixedF,

  -- ** Conditional formatting
  whenF,
  unlessF,

  -- ** Generic formatting
  genericF,
)
where

-- Generic useful things
import Data.List
import Lens.Micro
#if __GLASGOW_HASKELL__ < 804
import Data.Monoid ((<>))
#endif
#if __GLASGOW_HASKELL__ < 710
import Data.Monoid (mconcat, mempty)
#endif
-- Containers
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Set (Set)
import Data.IntMap (IntMap)
import qualified Data.IntMap as IntMap
import Data.IntSet (IntSet)
import qualified Data.IntSet as IntSet
import Data.Sequence (Seq)
#if MIN_VERSION_base(4,9,0)
import Data.List.NonEmpty (NonEmpty)
#endif
-- Text
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Data.Text (Text)
-- 'Buildable' and text-format stuff
import Formatting.Buildable
import qualified Formatting.Internal.Raw as F
-- Text 'Builder'
import Data.Text.Lazy.Builder hiding (fromString)
-- 'Foldable' and 'IsList' for list/map formatters
import Data.Foldable (toList)
#if __GLASGOW_HASKELL__ >= 708
import GHC.Exts (IsList, Item)
import qualified GHC.Exts as IsList (toList)
#endif
#if __GLASGOW_HASKELL__ < 710
import Data.Foldable (Foldable)
#endif
-- Generics
import GHC.Generics

import Fmt.Internal
import Fmt.Time

-- $setup
-- >>> :set -XOverloadedStrings
-- >>> :set -XDeriveGeneric

{- $overloadedstrings

You need @OverloadedStrings@ enabled to use this library. There are three
ways to do it:

  * __In GHCi:__ do @:set -XOverloadedStrings@.

  * __In a module:__ add @\{\-\# LANGUAGE OverloadedStrings \#\-\}@
    to the beginning of your module.

  * __In a project:__ add @OverloadedStrings@ to the @default-extensions@
    section of your @.cabal@ file.
-}

{- $examples

Here's a bunch of examples because some people learn better by looking at
examples.

Insert some variables into a string:

>>> let (a, b, n) = ("foo", "bar", 25)
>>> ("Here are some words: "+|a|+", "+|b|+"\nAlso a number: "+|n|+"") :: String
"Here are some words: foo, bar\nAlso a number: 25"

Print it:

>>> fmtLn ("Here are some words: "+|a|+", "+|b|+"\nAlso a number: "+|n|+"")
Here are some words: foo, bar
Also a number: 25

Format a list in various ways:

>>> let xs = ["John", "Bob"]

>>> fmtLn ("Using show: "+||xs||+"\nUsing listF: "+|listF xs|+"")
Using show: ["John","Bob"]
Using listF: [John, Bob]

>>> fmt ("YAML-like:\n"+|blockListF xs|+"")
YAML-like:
- John
- Bob

>>> fmt ("JSON-like: "+|jsonListF xs|+"")
JSON-like: [
  John
, Bob
]

-}

{- $migration

Instead of using @%@, surround variables with '+|' and '|+'. You don't have
to use @sformat@ or anything else, and also where you were using @build@,
@int@, @text@, etc in @formatting@, you don't have to use anything in @fmt@:

@
formatting    __sformat ("Foo: "%build%", bar: "%int) foo bar__
       fmt    __"Foo: "+|foo|+", bar: "+|bar|+""__
@

The resulting formatted string is polymorphic and can be used as 'String',
'Text', 'Builder' or even 'IO' (i.e. the string will be printed to the
screen). However, when printing it is recommended to use 'fmt' or 'fmtLn'
for clarity.

@fmt@ provides lots of formatters (which are simply functions that produce
'Builder'):

@
formatting    __sformat ("Got another byte ("%hex%")") x__
       fmt    __"Got another byte ("+|hexF x|+")"__
@

Instead of the @shown@ formatter, either just use 'show' or double brackets:

@
formatting    __sformat ("This uses Show: "%shown%") foo__
    fmt #1    __"This uses Show: "+|show foo|+""__
    fmt #2    __"This uses Show: "+||foo||+""__
@

Many formatters from @formatting@ have the same names in @fmt@, but with
added “F”: 'hexF', 'exptF', etc. Some have been renamed, though:

@
__Cutting:__
  fitLeft  -\> 'prefixF'
  fitRight -\> 'suffixF'

__Padding:__
  left   -\> 'padLeftF'
  right  -\> 'padRightF'
  center -\> 'padBothF'

__Stuff with numbers:__
  ords   -\> 'ordinalF'
  commas -\> 'commaizeF'
@

Also, some formatters from @formatting@ haven't been added to @fmt@
yet. Specifically:

* @plural@ and @asInt@ (but instead of @asInt@ you can use 'fromEnum')
* @prefixBin@, @prefixOrd@, @prefixHex@, and @bytes@
* formatters that use @Scientific@ (@sci@ and @scifmt@)

They will be added later. (On the other hand, @fmt@ provides some useful
formatters not available in @formatting@, such as 'listF', 'mapF', 'tupleF'
and so on.)
-}

----------------------------------------------------------------------------
-- Documentation for operators
----------------------------------------------------------------------------

{- $brackets

To format strings, put variables between ('+|') and ('|+'):

>>> let name = "Alice"
>>> "Meet "+|name|+"!" :: String
"Meet Alice!"

Of course, 'Text' is supported as well:

>>> "Meet "+|name|+"!" :: Text
"Meet Alice!"

You don't actually need any type signatures; however, if you're toying with
this library in GHCi, it's recommended to either add a type signature or use
'fmtLn':

>>> fmtLn ("Meet "+|name|+"!")
Meet Alice!

Otherwise the type of the formatted string would be resolved to @IO ()@ and
printed without a newline, which is not very convenient when you're in GHCi.
On the other hand, it's useful for quick-and-dirty scripts:

@
main = do
  [fin, fout] \<- words \<$\> getArgs
  __"Reading data from "+|fin|+"\\n"__
  xs \<- readFile fin
  __"Writing processed data to "+|fout|+"\\n"__
  writeFile fout (show (process xs))
@

Anyway, let's proceed. Anything 'Buildable', including numbers, booleans,
characters and dates, can be put between ('+|') and ('|+'):

>>> let starCount = "173"
>>> fmtLn ("Meet "+|name|+"! She's got "+|starCount|+" stars on Github.")
Meet Alice! She's got 173 stars on Github.

Since the only thing ('+|') and ('|+') do is concatenate strings and do
conversion, you can use any functions you want inside them. In this case,
'length':

>>> fmtLn (""+|name|+"'s name has "+|length name|+" letters")
Alice's name has 5 letters

If something isn't 'Buildable', just use 'show' on it:

>>> let pos = (3, 5)
>>> fmtLn ("Character's position: "+|show pos|+"")
Character's position: (3,5)

Or one of many formatters provided by this library – for instance, for tuples
of various sizes there's 'tupleF':

>>> fmtLn ("Character's position: "+|tupleF pos|+"")
Character's position: (3, 5)

Finally, for convenience there's the ('|++|') operator, which can be used if
you've got one variable following the other:

>>> let (a, op, b, res) = (2, "*", 2, 4)
>>> fmtLn (""+|a|++|op|++|b|+" = "+|res|+"")
2*2 = 4

Also, since in some codebases there are /lots/ of types which aren't
'Buildable', there are operators ('+||') and ('||+'), which use 'show'
instead of 'build':

prop> (""+|show foo|++|show bar|+"") == (""+||foo||++||bar||+"")
-}

-- $god1
-- Operators for the operators god!

-- $god2
-- More operators for the operators god!

{- $god3

Z̸͠A̵̕͟͠L̡̀́͠G̶̛O͝ ̴͏̀ I͞S̸̸̢͠  ̢̛͘͢C̷͟͡Ó̧̨̧͞M̡͘͟͞I̷͜N̷̕G̷̀̕

(Though you can just use @""@ between @+| |+@ instead of using these
operators, and 'Show'-brackets don't have to be used at all because there's
'show' available.)
-}

----------------------------------------------------------------------------
-- Text formatters
----------------------------------------------------------------------------

{- |
Indent a block of text.

>>> fmt $ "This is a list:\n" <> indentF 4 (blockListF [1,2,3])
This is a list:
    - 1
    - 2
    - 3

The output will always end with a newline, even when the input doesn't.
-}
indentF :: Int -> Builder -> Builder
indentF n a = case TL.lines (toLazyText a) of
    [] -> fromLazyText (spaces <> "\n")
    xs -> fromLazyText $ TL.unlines (map (spaces <>) xs)
  where
    spaces = TL.replicate (fromIntegral n) (TL.singleton ' ')

{- | Attach a name to anything:

>>> fmt $ nameF "clients" $ blockListF ["Alice", "Bob", "Zalgo"]
clients:
  - Alice
  - Bob
  - Zalgo
-}
nameF :: Builder -> Builder -> Builder
nameF k v = case TL.lines (toLazyText v) of
    []  -> k <> ":\n"
    [l] -> k <> ": " <> fromLazyText l <> "\n"
    ls  -> k <> ":\n" <>
           mconcat ["  " <> fromLazyText s <> "\n" | s <- ls]

{- | Put words between elements.

>>> fmt $ unwordsF ["hello", "world"]
hello world

Of course, it works on anything 'Buildable':

>>> fmt $ unwordsF [1, 2]
1 2
-}
unwordsF :: (Foldable f, Buildable a) => f a -> Builder
unwordsF = mconcat . intersperse " " . map build . toList

{-# SPECIALIZE unwordsF :: Buildable a => [a] -> Builder #-}

{- | Arrange elements on separate lines.

>>> fmt $ unlinesF ["hello", "world"]
hello
world
-}
unlinesF :: (Foldable f, Buildable a) => f a -> Builder
unlinesF = mconcat . map (nl . build) . toList
  where
    nl x | "\n" `TL.isSuffixOf` toLazyText x = x
         | otherwise = x <> "\n"

{-# SPECIALIZE unlinesF :: Buildable a => [a] -> Builder #-}

----------------------------------------------------------------------------
-- List formatters
----------------------------------------------------------------------------

{- | A simple comma-separated list formatter.

>>> listF ["hello", "world"]
"[hello, world]"

For multiline output, use 'jsonListF'.
-}
listF :: (Foldable f, Buildable a) => f a -> Builder
listF = listF' build
{-# INLINE listF #-}

{- | A version of 'listF' that lets you supply your own building function for
list elements.

For instance, to format a list of lists you'd have to do this (since there's
no 'Buildable' instance for lists):

>>> listF' listF [[1,2,3],[4,5,6]]
"[[1, 2, 3], [4, 5, 6]]"
-}
listF' :: (Foldable f) => (a -> Builder) -> f a -> Builder
listF' fbuild xs = mconcat $
  "[" :
  intersperse ", " (map fbuild (toList xs)) ++
  ["]"]

{-# SPECIALIZE listF' :: (a -> Builder) -> [a] -> Builder #-}

{- Note [Builder appending]
~~~~~~~~~~~~~~~~~~~~~~~~~~~

The documentation for 'Builder' says that it's preferrable to associate
'Builder' appends to the right (i.e. @a <> (b <> c)@). The maximum possible
association-to-the-right is achieved when we avoid appending builders until
the last second (i.e. in the latter scenario):

    -- (a1 <> x) <> (a2 <> x) <> ...
    mconcat [a <> x | a <- as]

    -- a1 <> x <> a2 <> x <> ...
    mconcat $ concat [[a, x] | a <- as]

However, benchmarks have shown that the former way is actually faster.
-}

{- | A multiline formatter for lists.

>>> fmt $ blockListF [1,2,3]
- 1
- 2
- 3

Multi-line elements are indented correctly:

>>> fmt $ blockListF ["hello\nworld", "foo\nbar\nquix"]
- hello
  world
- foo
  bar
  quix

-}
blockListF :: forall f a. (Foldable f, Buildable a) => f a -> Builder
blockListF = blockListF' "-" build
{-# INLINE blockListF #-}

{- | A version of 'blockListF' that lets you supply your own building function
for list elements (instead of 'build') and choose the bullet character
(instead of @"-"@).
-}
blockListF'
  :: forall f a. Foldable f
  => Text                       -- ^ Bullet
  -> (a -> Builder)             -- ^ Builder for elements
  -> f a                        -- ^ Structure with elements
  -> Builder
blockListF' bullet fbuild xs = if null items then "[]\n" else mconcat items
  where
    items = map buildItem (toList xs)
    spaces = mconcat $ replicate (T.length bullet + 1) (singleton ' ')
    buildItem x = case TL.lines (toLazyText (fbuild x)) of
      []     -> bullet |+ "\n"
      (l:ls) -> bullet |+ " " +| l |+ "\n" <>
                mconcat [spaces <> fromLazyText s <> "\n" | s <- ls]

{-# SPECIALIZE blockListF' :: Text -> (a -> Builder) -> [a] -> Builder #-}

{- | A JSON-style formatter for lists.

>>> fmt $ jsonListF [1,2,3]
[
  1
, 2
, 3
]

Like 'blockListF', it handles multiline elements well:

>>> fmt $ jsonListF ["hello\nworld", "foo\nbar\nquix"]
[
  hello
  world
, foo
  bar
  quix
]
-}
jsonListF :: forall f a. (Foldable f, Buildable a) => f a -> Builder
jsonListF = jsonListF' build
{-# INLINE jsonListF #-}

{- | A version of 'jsonListF' that lets you supply your own building function
for list elements.
-}
jsonListF' :: forall f a. (Foldable f) => (a -> Builder) -> f a -> Builder
jsonListF' fbuild xs
  | null items = "[]\n"
  | otherwise  = "[\n" <> mconcat items <> "]\n"
  where
    items = zipWith buildItem (True : repeat False) (toList xs)
    -- Item builder
    buildItem :: Bool -> a -> Builder
    buildItem isFirst x =
      case map fromLazyText (TL.lines (toLazyText (fbuild x))) of
        [] | isFirst   -> "\n"
           | otherwise -> ",\n"
        ls ->
            mconcat . map (<> "\n") $
              ls & _head %~ (if isFirst then ("  " <>) else (", " <>))
                 & _tail.each %~ ("  " <>)

{-# SPECIALIZE jsonListF' :: (a -> Builder) -> [a] -> Builder #-}

----------------------------------------------------------------------------
-- Map formatters
----------------------------------------------------------------------------

#if __GLASGOW_HASKELL__ >= 708
#  define MAPTOLIST IsList.toList
#else
#  define MAPTOLIST id
#endif

{- | A simple JSON-like map formatter; works for Map, HashMap, etc, as well as
ordinary lists of pairs.

>>> mapF [("a", 1), ("b", 4)]
"{a: 1, b: 4}"

For multiline output, use 'jsonMapF'.
-}
mapF ::
#if __GLASGOW_HASKELL__ >= 708
    (IsList t, Item t ~ (k, v), Buildable k, Buildable v) => t -> Builder
#else
    (Buildable k, Buildable v) => [(k, v)] -> Builder
#endif
mapF = mapF' build build
{-# INLINE mapF #-}

{- | A version of 'mapF' that lets you supply your own building function for
keys and values.
-}
mapF' ::
#if __GLASGOW_HASKELL__ >= 708
    (IsList t, Item t ~ (k, v)) =>
    (k -> Builder) -> (v -> Builder) -> t -> Builder
#else
    (k -> Builder) -> (v -> Builder) -> [(k, v)] -> Builder
#endif
mapF' fbuild_k fbuild_v xs =
  "{" <> mconcat (intersperse ", " (map buildPair (MAPTOLIST xs))) <> "}"
  where
    buildPair (k, v) = fbuild_k k <> ": " <> fbuild_v v

{- | A YAML-like map formatter:

>>> fmt $ blockMapF [("Odds", blockListF [1,3]), ("Evens", blockListF [2,4])]
Odds:
  - 1
  - 3
Evens:
  - 2
  - 4
-}
blockMapF ::
#if __GLASGOW_HASKELL__ >= 708
    (IsList t, Item t ~ (k, v), Buildable k, Buildable v) => t -> Builder
#else
    (Buildable k, Buildable v) => [(k, v)] -> Builder
#endif
blockMapF = blockMapF' build build
{-# INLINE blockMapF #-}

{- | A version of 'blockMapF' that lets you supply your own building function
for keys and values.
-}
blockMapF' ::
#if __GLASGOW_HASKELL__ >= 708
    (IsList t, Item t ~ (k, v)) =>
    (k -> Builder) -> (v -> Builder) -> t -> Builder
#else
    (k -> Builder) -> (v -> Builder) -> [(k, v)] -> Builder
#endif
blockMapF' fbuild_k fbuild_v xs
  | null items = "{}\n"
  | otherwise  = mconcat items
  where
    items = map (\(k, v) -> nameF (fbuild_k k) (fbuild_v v)) (MAPTOLIST xs)

{- | A JSON-like map formatter (unlike 'mapF', always multiline):

>>> fmt $ jsonMapF [("Odds", jsonListF [1,3]), ("Evens", jsonListF [2,4])]
{
  Odds:
    [
      1
    , 3
    ]
, Evens:
    [
      2
    , 4
    ]
}
-}
jsonMapF ::
#if __GLASGOW_HASKELL__ >= 708
    (IsList t, Item t ~ (k, v), Buildable k, Buildable v) => t -> Builder
#else
    (Buildable k, Buildable v) => [(k, v)] -> Builder
#endif
jsonMapF = jsonMapF' build build
{-# INLINE jsonMapF #-}

{- | A version of 'jsonMapF' that lets you supply your own building function
for keys and values.
-}
jsonMapF' ::
#if __GLASGOW_HASKELL__ >= 708
    forall t k v.
    (IsList t, Item t ~ (k, v)) =>
    (k -> Builder) -> (v -> Builder) -> t -> Builder
#else
    forall k v.
    (k -> Builder) -> (v -> Builder) -> [(k, v)] -> Builder
#endif
jsonMapF' fbuild_k fbuild_v xs
  | null items = "{}\n"
  | otherwise  = "{\n" <> mconcat items <> "}\n"
  where
    items = zipWith buildItem (True : repeat False) (MAPTOLIST xs)
    -- Item builder
    buildItem :: Bool -> (k, v) -> Builder
    buildItem isFirst (k, v) = do
      let kb = (if isFirst then "  " else ", ") <> fbuild_k k
      case map fromLazyText (TL.lines (toLazyText (fbuild_v v))) of
        []  -> kb <> ":\n"
        [l] -> kb <> ": " <> l <> "\n"
        ls  -> kb <> ":\n" <>
               mconcat ["    " <> s <> "\n" | s <- ls]

----------------------------------------------------------------------------
-- ADT formatters
----------------------------------------------------------------------------

{- | Like 'build' for 'Maybe', but displays 'Nothing' as @\<Nothing\>@ instead
of an empty string.

'build':

>>> build (Nothing :: Maybe Int)
""
>>> build (Just 1 :: Maybe Int)
"1"

'maybeF':

>>> maybeF (Nothing :: Maybe Int)
"<Nothing>"
>>> maybeF (Just 1 :: Maybe Int)
"1"
-}
maybeF :: Buildable a => Maybe a -> Builder
maybeF = maybe "<Nothing>" build

{- |
Format an 'Either':

>>> eitherF (Right 1 :: Either Bool Int)
"<Right: 1>"
-}
eitherF :: (Buildable a, Buildable b) => Either a b -> Builder
eitherF = either (\x -> "<Left: " <> build x <> ">")
                 (\x -> "<Right: " <> build x <> ">")

----------------------------------------------------------------------------
-- Other formatters
----------------------------------------------------------------------------

{- |
Take the first N characters:

>>> prefixF 3 "hello"
"hel"
-}
prefixF :: Buildable a => Int -> a -> Builder
prefixF size =
  fromLazyText . TL.take (fromIntegral size) . toLazyText . build

{- |
Take the last N characters:

>>> suffixF 3 "hello"
"llo"
-}
suffixF :: Buildable a => Int -> a -> Builder
suffixF size =
  fromLazyText .
  (\t -> TL.drop (TL.length t - fromIntegral size) t) .
  toLazyText . build

{- |
@padLeftF n c@ pads the string with character @c@ from the left side until it
becomes @n@ characters wide (and does nothing if the string is already that
long, or longer):

>>> padLeftF 5 '0' 12
"00012"
>>> padLeftF 5 '0' 123456
"123456"
-}
padLeftF :: Buildable a => Int -> Char -> a -> Builder
padLeftF = F.left

{- |
@padRightF n c@ pads the string with character @c@ from the right side until
it becomes @n@ characters wide (and does nothing if the string is already
that long, or longer):

>>> padRightF 5 ' ' "foo"
"foo  "
>>> padRightF 5 ' ' "foobar"
"foobar"
-}
padRightF :: Buildable a => Int -> Char -> a -> Builder
padRightF = F.right

{- |
@padBothF n c@ pads the string with character @c@ from both sides until
it becomes @n@ characters wide (and does nothing if the string is already
that long, or longer):

>>> padBothF 5 '=' "foo"
"=foo="
>>> padBothF 5 '=' "foobar"
"foobar"

When padding can't be distributed equally, the left side is preferred:

>>> padBothF 8 '=' "foo"
"===foo=="
-}
padBothF :: Buildable a => Int -> Char -> a -> Builder
padBothF i c =
  fromLazyText . TL.center (fromIntegral i) c . toLazyText . build

----------------------------------------------------------------------------
-- Conditional formatters
----------------------------------------------------------------------------

{- | Display something only if the condition is 'True' (empty string
otherwise).

Note that it can only take a 'Builder' (because otherwise it would be
unusable with ('+|')-formatted strings which can resolve to any
'FromBuilder'). You can use 'build' to convert any value to a 'Builder'.
-}
whenF :: Bool -> Builder -> Builder
whenF True  x = x
whenF False _ = mempty
{-# INLINE whenF #-}

{- | Display something only if the condition is 'False' (empty string
otherwise).
-}
unlessF :: Bool -> Builder -> Builder
unlessF False x = x
unlessF True  _ = mempty
{-# INLINE unlessF #-}

----------------------------------------------------------------------------
-- Generic formatting
----------------------------------------------------------------------------

{- | Format an arbitrary value without requiring a 'Buildable' instance:

>>> data Foo = Foo { x :: Bool, y :: [Int] } deriving Generic

>>> fmt (genericF (Foo True [1,2,3]))
Foo:
  x: True
  y: [1, 2, 3]

It works for non-record constructors too:

>>> data Bar = Bar Bool [Int] deriving Generic

>>> fmtLn (genericF (Bar True [1,2,3]))
<Bar: True, [1, 2, 3]>

Any fields inside the type must either be 'Buildable' or one of the following
types:

* a function
* a tuple (up to 8-tuples)
* list, 'NonEmpty', 'Seq'
* 'Map', 'IntMap', 'Set', 'IntSet'
* 'Maybe', 'Either'

The exact format of 'genericF' might change in future versions, so don't rely
on it. It's merely a convenience function.
-}
genericF :: (Generic a, GBuildable (Rep a)) => a -> Builder
genericF = gbuild . from

instance GBuildable a => GBuildable (M1 D d a) where
  gbuild (M1 x) = gbuild x

instance (GetFields a, Constructor c) => GBuildable (M1 C c a) where
  -- A note on fixity:
  --   * Ordinarily e.g. "Foo" is prefix and e.g. ":|" is infix
  --   * However, "Foo" can be infix when defined as "a `Foo` b"
  --   * And ":|" can be prefix when defined as "(:|) a b"
  gbuild c@(M1 x) = case conFixity c of
    Infix _ _
      | [a, b] <- fields -> format "({} {} {})" a infixName b
      -- this case should never happen, but still
      | otherwise        -> format "<{}: {}>"
                              prefixName
                              (mconcat (intersperse ", " fields))
    Prefix
      | isTuple -> tupleF fields
      | conIsRecord c -> nameF (build prefixName) (blockMapF fieldsWithNames)
      | null (getFields x) -> build prefixName
      -- I believe that there will be only one field in this case
      | null (conName c) -> mconcat (intersperse ", " fields)
      | otherwise -> format "<{}: {}>"
                       prefixName
                       (mconcat (intersperse ", " fields))
    where
      (prefixName, infixName)
        | ":" `isPrefixOf` conName c = ("(" ++ conName c ++ ")", conName c)
        | otherwise                  = (conName c, "`" ++ conName c ++ "`")
      fields          = map snd (getFields x)
      fieldsWithNames = getFields x
      isTuple         = "(," `isPrefixOf` prefixName

instance Buildable' c => GBuildable (K1 i c) where
  gbuild (K1 a) = build' a

instance (GBuildable a, GBuildable b) => GBuildable (a :+: b) where
  gbuild (L1 x) = gbuild x
  gbuild (R1 x) = gbuild x

instance (GetFields a, GetFields b) => GetFields (a :*: b) where
  getFields (a :*: b) = getFields a ++ getFields b

instance (GBuildable a, Selector c) => GetFields (M1 S c a) where
  getFields s@(M1 a) = [(selName s, gbuild a)]

instance GBuildable a => GetFields (M1 D c a) where
  getFields (M1 a) = [("", gbuild a)]

instance GBuildable a => GetFields (M1 C c a) where
  getFields (M1 a) = [("", gbuild a)]

instance GetFields U1 where
  getFields _ = []

----------------------------------------------------------------------------
-- A more powerful Buildable used for genericF
----------------------------------------------------------------------------

instance Buildable' () where
  build' _ = "()"

instance (Buildable' a1, Buildable' a2)
  => Buildable' (a1, a2) where
  build' (a1, a2) = tupleF
    [build' a1, build' a2]

instance (Buildable' a1, Buildable' a2, Buildable' a3)
  => Buildable' (a1, a2, a3) where
  build' (a1, a2, a3) = tupleF
    [build' a1, build' a2, build' a3]

instance (Buildable' a1, Buildable' a2, Buildable' a3, Buildable' a4)
  => Buildable' (a1, a2, a3, a4) where
  build' (a1, a2, a3, a4) = tupleF
    [build' a1, build' a2, build' a3, build' a4]

instance (Buildable' a1, Buildable' a2, Buildable' a3, Buildable' a4,
          Buildable' a5)
  => Buildable' (a1, a2, a3, a4, a5) where
  build' (a1, a2, a3, a4, a5) = tupleF
    [build' a1, build' a2, build' a3, build' a4,
     build' a5]

instance (Buildable' a1, Buildable' a2, Buildable' a3, Buildable' a4,
          Buildable' a5, Buildable' a6)
  => Buildable' (a1, a2, a3, a4, a5, a6) where
  build' (a1, a2, a3, a4, a5, a6) = tupleF
    [build' a1, build' a2, build' a3, build' a4,
     build' a5, build' a6]

instance (Buildable' a1, Buildable' a2, Buildable' a3, Buildable' a4,
          Buildable' a5, Buildable' a6, Buildable' a7)
  => Buildable' (a1, a2, a3, a4, a5, a6, a7) where
  build' (a1, a2, a3, a4, a5, a6, a7) = tupleF
    [build' a1, build' a2, build' a3, build' a4,
     build' a5, build' a6, build' a7]

instance (Buildable' a1, Buildable' a2, Buildable' a3, Buildable' a4,
          Buildable' a5, Buildable' a6, Buildable' a7, Buildable' a8)
  => Buildable' (a1, a2, a3, a4, a5, a6, a7, a8) where
  build' (a1, a2, a3, a4, a5, a6, a7, a8) = tupleF
    [build' a1, build' a2, build' a3, build' a4,
     build' a5, build' a6, build' a7, build' a8]

instance _OVERLAPPING_ Buildable' [Char] where
  build' = build

instance Buildable' a => Buildable' [a] where
  build' = listF' build'

#if MIN_VERSION_base(4,9,0)
instance Buildable' a => Buildable' (NonEmpty a) where
  build' = listF' build'
#endif

instance Buildable' a => Buildable' (Seq a) where
  build' = listF' build'

instance (Buildable' k, Buildable' v) => Buildable' (Map k v) where
  build' = mapF' build' build' . Map.toList

instance (Buildable' v) => Buildable' (Set v) where
  build' = listF' build'

instance (Buildable' v) => Buildable' (IntMap v) where
  build' = mapF' build' build' . IntMap.toList

instance Buildable' IntSet where
  build' = listF' build' . IntSet.toList

instance (Buildable' a) => Buildable' (Maybe a) where
  build' Nothing  = maybeF (Nothing         :: Maybe Builder)
  build' (Just a) = maybeF (Just (build' a) :: Maybe Builder)

instance (Buildable' a, Buildable' b) => Buildable' (Either a b) where
  build' (Left  a) = eitherF (Left  (build' a) :: Either Builder Builder)
  build' (Right a) = eitherF (Right (build' a) :: Either Builder Builder)

instance Buildable' (a -> b) where
  build' _ = "<function>"

instance _OVERLAPPABLE_ Buildable a => Buildable' a where
  build' = build

----------------------------------------------------------------------------
-- TODOs
----------------------------------------------------------------------------

{- docs
~~~~~~~~~~~~~~~~~~~~
* write explicitly that 'build' can be used and is useful sometimes
* mention that fmt doesn't do the neat thing that formatting does with (<>)
  (or maybe it does? there's a monoid instance for functions after all,
  though I might also have to write a IsString instance for (a -> Builder))
* write that if +| |+ are hated or if it's inconvenient in some cases,
  you can just use provided formatters and <> (add Fmt.DIY for that?)
  (e.g. "pub:" <> base16F foo)
* write that it can be used in parallel with formatting? can it, actually?
* clarify what exactly is hard about writing `formatting` formatters
-}

{- others
~~~~~~~~~~~~~~~~~~~~
* what effect does it have on compilation time? what effect do
  other formatting libraries have on compilation time?
-}
