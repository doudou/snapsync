module Kernel
  def human_readable_time(time)
    hrs = time / 3600
    min = (time / 60) % 60
    sec = time % 60
    "%02i:%02i:%02i" % [hrs, min, sec]
  end

  def human_readable_size(size, digits: 1)
    order = ['B', 'kB', 'MB', 'GB']
    magnitude =
      if size > 0
        Integer(Math.log2(size) / 10)
      else 0
      end
    "%.#{digits}f#{order[magnitude]}" % [Float(size) / (1024 ** magnitude)]
  end
end
