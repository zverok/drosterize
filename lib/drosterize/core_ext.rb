# encoding: utf-8
module Scale
  refine Numeric do
    def scale(from, to)
      (self-from.begin).to_f/(from.end-from.begin)*(to.end-to.begin)+to.begin
    end
  end
end
