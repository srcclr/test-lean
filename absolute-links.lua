-- https://github.com/jgm/pandoc/issues/4894
function Image (img)
  if img.src:sub(1,1) == '/' then
    img.src = img.src:sub(2)
  end
  return img
end
