-- render draws with love.graphics, which needs a window; it stays hidden
function love.conf(t)
  t.window.width, t.window.height = 240, 160
  t.window.visible = false
  t.modules.audio = false
  t.modules.sound = false
end
