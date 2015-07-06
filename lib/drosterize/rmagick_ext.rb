class Magick::Image
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

    Pixel.new(
      Interplolate.bilinear(c, r, fq11.red, fq12.red, fq21.red, fq22.red),
      Interplolate.bilinear(c, r, fq11.green, fq12.green, fq21.green, fq22.green),
      Interplolate.bilinear(c, r, fq11.blue, fq12.blue, fq21.blue, fq22.blue),
    )
  end
end
