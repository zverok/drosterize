# encoding: utf-8
require 'rmagick'
require 'ostruct'
require 'parallel'

require_relative 'drosterize/core_ext'
require_relative 'drosterize/rmagick_ext'
require_relative 'drosterize/geom'

class Drosterize
  include Magick
  using Scale
  using ArrayToImglist
  
  def initialize(img, topleft, bottomright)
    @rect = Geom::Rect.new(topleft, bottomright)

    # The algo only works for image with same center as an inside
    # frame center; and same aspect ratio.
    @src = img.crop_to_ratio(@rect.aspect_ratio, @rect.center)
    
    @scale = @rect.width.to_f / @src.width

    # Typically, aspect ratio is defined as width/height,
    # but in Jon's algo reverse relation is used
    @ratio = 1 / @rect.aspect_ratio

    # Some caching
    @width, @height = @src.width, @src.height

    # Those two rectangles are in "math" coordinate space for checking
    # whether coords are inside/outside (look at #ensure_replication)
    @math_borders = Geom::Rect.new([-1, -@ratio], [1, @ratio])
    @math_frame = Geom::Rect.new([-@scale, -@scale*@ratio], [@scale, @scale*@ratio])
  end

  DEFAULT_OPTS = {
    # Full options as in Wolfram example - feel free to experiment with them
    #zoom: 1,
    #xshift: 0,
    #yshift: 0,
    #rotation: 0,

    copies: 1,
    spirals: 1
  }
  
  def drosterize(opts = {})
    opts = OpenStruct.new(DEFAULT_OPTS.merge(opts.reject{|k, v| !v}))

    @src.transform{|px, x, y|
      @src.pixel_color_f(*transform_coords(x, y, opts))
    }
  end

  # In fact, very slow due to data marshalling between processes
  def parallel_drosterize(opts = {})
    opts = OpenStruct.new(DEFAULT_OPTS.merge(opts.reject{|k, v| !v}))

    num_slices = Parallel.processor_count
    swidth = @width / num_slices

    Parallel.map((0...num_slices)){|slice|
      dx = slice*swidth
      @src.crop(dx, 0, swidth, @height, true).transform{|px, x, y|
        @src.pixel_color_f(*transform_coords(x + dx, y, opts))
      }
    }.to_imglist.append(false)
  end

  private

  # The wrapper around real math, only transforming coordinates
  # from "image" (real RMagick's pixel coordinates) space
  # to "math" space (where "spiralling" math works)
  def transform_coords(x, y, opts)
    to_img_space(*transform_coords_math(*to_math_space(x, y), opts))
  end

  # Transforms from (0..width, 0..height) to (-1..-1, -ratio..ratio) space
  def to_math_space(x, y)
    [x.scale(0...@width, -1...1), y.scale(0...@height, -@ratio...@ratio)]
  end

  # Transforms from (-1..-1, -ratio..ratio) to (0..width, 0..height) space
  def to_img_space(x, y)
    [x.scale(-1...1, 0...@width), y.scale(-@ratio...@ratio, 0...@height)]
  end

  include Math
  I = Complex::I

  # The REAL magic of spiralling is here
  # All credits for the formula should go to author of the
  # original article: http://blog.wolfram.com/2009/04/24/droste-effect-with-mathematica/
  #
  # Note, that when spirals == 0, all the complicated math is degenerates
  # to just call of ensure_replication
  #
  # x, y => (x + I*y)**(1+0*(...)) => x + I*y => (x, y)
  #
  def transform_coords_math(x, y, opts)
    coords =
      if x.zero? && y.zero?
        0 # Wolfram thinks 0^(a+bi) is 0, while Ruby thinks its NaN
      else
        # Full formula as in Jon's code
        #opts.zoom *
          #E**(I*opts.rotation) *
          #(opts.xshift + I*opts.yshift + point.x + I * point.y)**
            #(opts.copies+opts.spirals*I*log(@scale)/2*PI)

        # Simplified formula, using only some of the options
        (x + I * y)**
          (opts.copies+opts.spirals*I*log(@scale)/(2*PI))
      end

    ensure_replication(coords.real, coords.imaginary)
  end

  # The magic of self-replication is here and it's pretty simple
  # * for currently calculated coordinate, if it's inside frame
  #   (which will contain replica), proportionally move outside
  # * if it's outside image (possible when spirals calculated) -
  #   proportionally move inside
  def ensure_replication(x, y, max_iterations = 10)
    max_iterations.times do
      case
      when !@math_borders.cover?(x, y)
        x, y = x * @scale, y * @scale # outside of image: move closer
      when @math_frame.cover?(x, y)
        x, y = x / @scale, y / @scale # inside the frame: move out
      else
        break
      end
    end
    
    [x, y]
  end
end
