-- 扫描技能 — 用 lfs 扫描周围环境

local M = {}

function M.name()
    return 'scan'
end

function M.execute()
    print('[skill:scan] 扫描周边环境...')

    -- 用 lfs 列出当前目录文件（演示文件系统库）
    local files = {}
    for name in lfs.dir('.') do
        if name ~= '.' and name ~= '..' then
            files[#files + 1] = name
        end
    end

    print(string.format('[skill:scan] 发现 %d 个目标', #files))
    return files
end

return M
