local M = {}

-- 计算向量长度
local function vector_length(v)
  return math.sqrt(v[1] * v[1] + v[2] * v[2])
end

-- 向量标准化
local function normalize_vector(v)
  local length = vector_length(v)
  return {v[1] / length, v[2] / length}
end

-- 向量加法
local function vector_add(v1, v2)
  return {v1[1] + v2[1], v1[2] + v2[2]}
end

-- 向量减法
local function vector_sub(v1, v2)
  return {v1[1] - v2[1], v1[2] - v2[2]}
end

-- 向量乘以标量
local function vector_mul(v, scalar)
  return {v[1] * scalar, v[2] * scalar}
end

local function cubic_bezier_control_points(p0, p3, distance1, distance2, t1, t2)
  t1 = t1 or 0.3
  t2 = t2 or 0.3
  
  -- 计算方向向量
  local line_vector = vector_sub(p3, p0)
  local line_length = vector_length(line_vector)
  local direction = normalize_vector(line_vector)
  
  -- 计算法向量 (90度旋转)
  local normal = {-direction[2], direction[1]}
  
  -- 计算控制点在连线上的投影点
  local p1_proj = vector_add(p0, vector_mul(direction, line_length * t1))
  local p2_proj = vector_sub(p3, vector_mul(direction, line_length * t2))
  
  -- 计算控制点
  local p1 = vector_add(p1_proj, vector_mul(normal, distance1))
  local p2 = vector_add(p2_proj, vector_mul(normal, distance2))
  
  return p1, p2
end


local function cubic_bezier(p0, p1, p2, p3, steps)
  local path = {}
  for i = 0, steps do
    local t = i / steps
    local mt = 1 - t
    local x = mt^3 * p0[1] + 3 * mt^2 * t * p1[1] + 3 * mt * t^2 * p2[1] + t^3 * p3[1]
    local y = mt^3 * p0[2] + 3 * mt^2 * t * p1[2] + 3 * mt * t^2 * p2[2] + t^3 * p3[2]
    table.insert(path, {x, y})
  end
  return path
end

function M.generatePath(ox, oy, tx, ty, distance1, distance2, steps)
  local op,tp = {ox,oy},{tx,ty}
  local cp1, cp2 = cubic_bezier_control_points(op, tp, distance1, distance2)
  local path = cubic_bezier(op, cp1, cp2, tp, steps)
  return path
end

return M