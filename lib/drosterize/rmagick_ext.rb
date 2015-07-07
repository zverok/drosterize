require_relative 'interpolate'

class Magick::Image
  alias_method :width, :columns
  alias_method :height, :rows
  
  def rect
    @rect ||= Geom::Rect.new([0, 0], [width, height])
  end

  # Crop image to have designated aspect ratio
  # Optionally provide "crop center" - cropped result should have it as a center
  def crop_to_ratio(aspect_ratio, center = nil)
    center ||= rect.center
    xcenter, ycenter = center

    # maximal possible width & height, if center would be (xcenter, ycenter)
    wmax = [xcenter, (width - xcenter)].min * 2
    hmax = [ycenter, (height - ycenter)].min * 2

    wcrop = hmax * aspect_ratio
    hcrop = wmax / aspect_ratio

    w = [wmax, wcrop].min
    h = [hmax, hcrop].min

    crop(xcenter - w/2, ycenter - h/2, w, h, true)
  end

  # pixel color with float coords
  # does bilinear interpolation of four pixels around coordinates
  def pixel_color_f(c, r)
    c1, c2 = c.floor, c.ceil
    r1, r2 = r.floor, r.ceil
    return pixel_color(c, r) if c1 == c2 && r1 == r2
    
    fq11 = pixel_color(c1, r1)
    fq12 = pixel_color(c1, r2)
    fq21 = pixel_color(c2, r1)
    fq22 = pixel_color(c2, r2)

    Magick::Pixel.new(
      Interplolate.bilinear(c, r, fq11.red, fq12.red, fq21.red, fq22.red),
      Interplolate.bilinear(c, r, fq11.green, fq12.green, fq21.green, fq22.green),
      Interplolate.bilinear(c, r, fq11.blue, fq12.blue, fq21.blue, fq22.blue),
    )
  end

  # Transform image to another one
  # Receives block, then for each (x,y) of source image calls block to
  # determine pixel color at (x,y) of target image
  def transform
    res = Magick::Image.new(columns, rows){self.background_color = 'white'}
    
    (0...columns).each do |c|
      (0...rows).each do |r|
        px = pixel_color(c, r)
        res.pixel_color(c, r, yield(px, c, r))
      end
    end
    res
  end
end

module ArrayToImglist
  refine Array do
    def to_imglist
      res = Magick::ImageList.new
      each{|i| res.push(i)}
      res
    end
  end
end
