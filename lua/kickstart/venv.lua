-- venv.lua
-- Helpers to find project virtualenvs (.venv or venv) for Python tooling.
-- Use for LSP (Pyright), lint (Ruff), and DAP (debugpy) so they use the same interpreter.

local M = {}

local function is_dir(path)
  if not path then return false end
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == 'directory'
end

local function path_join(...)
  return table.concat({ ... }, '/')
end

--- Find the first directory that looks like a venv (has bin/python or Scripts/python.exe).
local function is_venv_root(path)
  if not path or not is_dir(path) then return false end
  local bin_python = path_join(path, 'bin', 'python')
  local scripts_python = path_join(path, 'Scripts', 'python.exe')
  return vim.uv.fs_stat(bin_python) or vim.uv.fs_stat(scripts_python)
end

--- Walk up from `start_dir` looking for .venv or venv. Returns venv root path or nil.
--- @param start_dir string Directory to start from (e.g. buffer path or cwd).
--- @return string|nil Path to venv root (e.g. /project/.venv) or nil.
function M.get_venv_path(start_dir)
  if not start_dir or start_dir == '' then return nil end
  -- Normalize: remove trailing slash, resolve to absolute if needed
  local dir = vim.fn.fnamemodify(start_dir, ':p:h')
  local root = vim.uv.os_homedir()
  if dir == '' then return nil end

  while dir and dir ~= '' and #dir >= #root do
    for _, name in ipairs({ '.venv', 'venv' }) do
      local candidate = path_join(dir, name)
      if is_venv_root(candidate) then
        return candidate
      end
    end
    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent == dir then break end
    dir = parent
  end
  return nil
end

--- Venv path for the current buffer (file's directory, then cwd).
--- @return string|nil
function M.get_venv_path_for_buf()
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path and buf_path ~= '' then
    local p = M.get_venv_path(buf_path)
    if p then return p end
  end
  return M.get_venv_path(vim.fn.getcwd())
end

--- Python executable to use: venv's python or nil (use system/default).
--- @param venv_path string|nil From M.get_venv_path_for_buf() or M.get_venv_path(dir).
--- @return string
function M.get_python_path(venv_path)
  if not venv_path then return nil end
  local win = path_join(venv_path, 'Scripts', 'python.exe')
  local unix = path_join(venv_path, 'bin', 'python')
  if vim.uv.fs_stat(win) then return win end
  if vim.uv.fs_stat(unix) then return unix end
  return nil
end

--- Ruff executable: venv's ruff or nil (use $PATH ruff).
--- @param venv_path string|nil
--- @return string|nil
function M.get_ruff_path(venv_path)
  if not venv_path then return nil end
  local win = path_join(venv_path, 'Scripts', 'ruff.exe')
  local unix = path_join(venv_path, 'bin', 'ruff')
  if vim.uv.fs_stat(win) then return win end
  if vim.uv.fs_stat(unix) then return unix end
  return nil
end

return M
