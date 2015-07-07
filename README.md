# Drosterize

**Drosterize** is yet another experiment on translating image-processing
code from Wolfram Language to Ruby. Previous was
[xkcdize](https://github.com/zverok/xkcdize), take a look.

Source of current experiment was an article by
[Jon McLoone](http://blog.wolfram.com/author/jon-mcloone/), named
[Droste Effect with Mathematica](http://blog.wolfram.com/2009/04/24/droste-effect-with-mathematica/).

Drosterize does "[Droste effect](https://en.wikipedia.org/wiki/Droste_effect)"
(self-including recursive images).

Here's some examles, and after them is algorithm description and some
reflections on its implementation.

Source:

<img src="https://raw.github.com/zverok/drosterize/master/examples/tardis.jpg" width="420" height="262">
([Image credits](http://the-hunger-games-users.wikia.com/wiki/File:Tardis-david-tennant-doctor-who-tenth-doctor-HD-Wallpapers.jpg))

Simplest self-replication (l-t-r-b is left-top-right-bottom of white plate on Tardis' door):

```
./bin/drosterize -f examples/tardis.jpg -l 409 -t 439 -r 635 -b 710 --spirals 0 -o examples/tardis-copies.jpg
```

<img src="https://raw.github.com/zverok/drosterize/master/examples/tardis-copies.jpg" width="396" height="476">

The same effect with spiral:

```
./bin/drosterize -f examples/tardis.jpg -l 409 -t 439 -r 635 -b 710 --spirals 1 -o examples/tardis-copies.jpg
```

<img src="https://raw.github.com/zverok/drosterize/master/examples/tardis-spiral.jpg" width="396" height="476">

Or with two spirals:

```
./bin/drosterize -f examples/tardis.jpg -l 409 -t 439 -r 635 -b 710 --spirals 2 -o examples/tardis-copies.jpg
```

<img src="https://raw.github.com/zverok/drosterize/master/examples/tardis-2spirals.jpg" width="396" height="476">

## Algorithm description

**NB**: ALL algorithm credits belong to Jon McLoone, author of original
article.

(It took two days for me to reverse-engineer it from code. Sometimes I
even think the Wolfram Language is _intetionally_ obscure... Don't know)

1. User provides source image and coordinates (topleft and bottomright)
  of rectangle, which will contain replications. Typically, selected
  rectangle should be in some frame or borders, for smoother outlook.
2. This algorithm works only when image and frame have same centers and
  same aspect ratios. So, next thing to do is image cropping.
3. For each (x, y) of output image we calculate which point of input
  image it should be copied from:
  * if there's no spiralling (see first example above), the logic is
    simple: if (x,y) is inside frame, they are scaled by frame-to-image
    coefficient and taken from that point, otherwise just copied from
    source image untouched
  * spirals are complicated! they are calculated by treating (x,y) as
    a complex number `x + iy` and then doint very nasty things with powers
    and logarithms; and then above logic (scaling if inside frame) is
    applied
4. All math should be done in "symmetrical" coordinates space (with `0,0`
  at center of the image), so, there is a need to convert each coordinate
  pair

## Implementation highlights

* RMagick is still the only Ruby image manipulation library which can be
  "just used". Though, for this case I've used almost none of its features, just
  "get pixel color" and "set pixel color" -- so, maybe some simpler library
  could do the task as well;
* I've tried to keep Ruby code as clean and Rubyish as possible; so, I've
  monkey-patched some RMagick classes, refined `Numeric`, utilized
  `OpenStruct`-wrapped options and so on;
* Two methods have prooved they extreme usability: `Image#pixel_color_f` and
  `Image#transform`;
* `#pixel_color_f` I've done for [xkcdize](https://github.com/zverok/xkcdize),
  it just takes pixel color by _non-integer_ coordinates, interpolating
  surrounding pixels;
* `#transform` also can be seen in xkcdize (where it
  has a dumb name `ImageList#map_to_image`), and it is common concept
  can be seen in [Wolfram](https://reference.wolfram.com/language/ref/ImageTransformation.html)
  as well as in ImageMagick `convert` interface (where it's called
  [fx](http://www.imagemagick.org/script/fx.php)). The idea is to transform
  some image to another point-by-point, where user provides definition
  of such a transformation (via Ruby block in our case);
* On parallelism: to be head-on-head with Jon's code, I've tried to use
  [parallel](https://github.com/grosser/parallel) gem, which seems a good
  idea on 4-core notebook... Yet the problem is the task not only computational-
  heavy, it's also data-heavy. It means that transferring data to child
  processes (which parallel do by `Marshal`-ing them) adds so much
  overhead that it is killing the entire idea. And multithread (instead of
  multiprocess) attempt was just as slow as single-thread -- maybe it
  is because of the GIL or ... Don't know. I left `Drosterize#parallel_drosterize`
  in `lib/drosterize.rb`, so you can take a look and experiment with;
* I have not implemented all the options from Jon's article (in fact,
  I've copied the formula, but then commented it out: it's still there)

## Lessons learned

* Wolfram code not always easy to read! Or its just me... Also, math
  is hard, yet powerful;
* There is several things which can be added to Ruby image processing
  (think RMagick) to make it more suitable for everyday experiment with
  images;
* Ruby IS slow, at least for a large amount of simple computations;
  profiling report for drosterize show most time (tens of seconds!) is
  taken by things like `Float#abs`, `Complex#**` and so on. Okay, there
  are millions of them, but it still doesn't look really cool... Still
  thinking on potential solutions (like using NMatrix and so on)
* Simple abstractions can be really pricey. At first, I've used `Point`
  and `Rectangle` classes from [geometry](https://github.com/bfoz/geometry)
  gem; code was pretty yet overhead (shown by profiling) was really awful.
  Finally I've dropped the gem completely and used just `[x,y]` for pairs
  of coordinates and very simple custom Rectangle implementation; also,
  I've dropped almost all smart refinements and monkey-patches to core
  classes, despite my love to them;
* Low-level abstactions are vague. There's dozens of implementations for
  things like `Point` or `Rectangle` (in fact, RMagick also
  [have them](https://rmagick.github.io/struct.html#Rectangle)
  as a very simple utility structs), but when you're really start needing
  them, there's no confidence of whether some gem should be used, or
  you need to implement them from scratch, and what functionality should
  go to those "basic" classes (like `Point#inside?(rect)` or `Rect#cover?(point)`),
  and how to "teach" other gems to work with your abstractions, so, you
  eventually find yourself with bare pairs of coordinates. It is not the
  Ruby way we like
* There is no point in using non-Ruby metaphors in Ruby code. While
  translating code from Wolfram, I was fascinated with FixedPoint concept:
  `fixed_point(10){|x| do_something(x)}` will call `do_something` on results
  of previous function... Until "fixed point" (value not changing)
  will be reached (or max iterations pass). The port was pretty straightforward,
  yet as a basic construct in code it looked confusing -- as if "I don't
  want to read this guy's code". (You can look at `Drosterize#ensure_replication`
  to see what I've done without this function. For me, the intention and
  code is pretty clear without that "cool" feature.)
  
## Credits & license

It's not a gem, just an experiment, so, lets think of it as a public
domain for a greater good. Written by Victor Shepelev, in train on his
way to the lovely Odessa city.

All credits for original algo and many thanks for inspiration are going
to [Jon McLoone](http://blog.wolfram.com/author/jon-mcloone/).
