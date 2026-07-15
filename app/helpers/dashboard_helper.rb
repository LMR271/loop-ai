module DashboardHelper
  def loop_avatar_gradient(loop_record)
    hue = loop_record.id.to_s.sum * 37 % 360
    "background: linear-gradient(135deg, hsl(#{hue}, 70%, 65%), hsl(#{(hue + 60) % 360}, 70%, 70%));"
  end
end
