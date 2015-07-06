module Interplolate
  module_function

  # See http://en.wikipedia.org/wiki/Bilinear_interpolation
  def bilinear(c, r, fq11, fq12, fq21, fq22)
    c1, c2 = c.floor, c.ceil
    r1, r2 = r.floor, r.ceil

    fr1 = fq11 * ((c2 - c) / (c2 - c1)) + fq21 * ((c - c1) / (c2 - c1))
    fr2 = fq12 * ((c2 - c) / (c2 - c1)) + fq22 * ((c - c1) / (c2 - c1))

    fr1 * ((r2 - r) / (r2 - r1)) + fr2 * ((r - r1) / (r2 - r1))
  end
end
