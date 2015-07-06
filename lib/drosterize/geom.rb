# encoding: utf-8
module Geom
  class Rect
    def initialize(topleft, bottomright)
      @xmin, @ymin = topleft
      @xmax, @ymax = bottomright
    end

    attr_reader :xmin, :xmax, :ymin, :ymax

    def width
      xmax - xmin
    end

    def height
      ymax - ymin
    end

    def center
      [xmin + width/2, ymin + height/2]
    end

    def aspect_ratio
      width.to_f / height.to_f
    end

    def cover?(x, y)
      (xmin...xmax).cover?(x) && (ymin...ymax).cover?(y)
    end
  end
end
