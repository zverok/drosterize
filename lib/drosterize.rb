# encoding: utf-8
require 'rmagick'
require 'ostruct'
require_relative 'drosterize/core_ext'
require_relative 'drosterize/rmagick_ext'
require_relative 'drosterize/geom'

class Drosterize
  include Magick
  using Scale
  
  def initialize(img, topleft, bottomright)
    @rect = Geom::Rect.new(topleft, bottomright)
    @src = img.crop_to_ratio(@rect.aspect_ratio, @rect.center)
    
    @scale = @rect.width.to_f / @src.rect.width

    # Typically, aspect ratio is defined as width/height,
    # but in Jon's algo reverse relation is used
    @ratio = 1 / @rect.aspect_ratio 
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
    opts = OpenStruct.new(DEFAULT_OPTS.merge(opts))

    @src.transform2{|px, x, y|
      @src.pixel_color_f(*transform_coords(x, y, opts))
    }
  end

  private

  def transform_coords(x, y, opts)
    to_img_space(*transform_coords_math(*to_math_space(x, y), opts))
  end

  # Transforms from (0..width, 0..height) to (-1..-1, -ratio..ratio) space
  def to_math_space(x, y)
    [x.scale(0...@src.width, -1...1), y.scale(0...@src.height, -@ratio...@ratio)]
  end

  # Transforms from (-1..-1, -ratio..ratio) to (0..width, 0..height) space
  def to_img_space(x, y)
    [x.scale(-1...1, 0...@src.width), y.scale(-@ratio...@ratio, 0...@src.height)]
  end

  include Math
  I = Complex::I

  def transform_coords_math(x, y, opts)
    coords =
      if x.zero? && y.zero?
        0 # Wolfram thinks 0^(a+bi) is 0, while Ruby thinks its NaN
      else
        # Full formula as in Wolfram example
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

  def ensure_replication(x, y, max_iterations = 10)
    max_iterations.times do
      case
      when x.abs > 1 || y.abs > @ratio #!p.inside?(@src.rect)
        x, y = x * @scale, y * @scale # outside of image: move closer
      when x.abs < @scale && y.abs < @scale*@ratio #p.inside?(@rect)
        x, y = x / @scale, y / @scale # inside the frame: move out
      else
        break
      end
    end
    
    [x, y]
  end
end
