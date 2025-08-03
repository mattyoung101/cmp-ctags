local uv = vim.loop

local Pipe = {}

Pipe.new = function()
  local self = setmetatable({}, { __index = Pipe })
  self.pipe = uv.new_pipe()
  self.output = ""
  return self
end

function Pipe:close()
  self.pipe:close()
end

function Pipe:read_start()
  uv.read_start(self.pipe, function(err, chunk)
    assert(not err, err)
    if chunk then
      self.output = self.output .. chunk
    end
  end)
end

local Process = {}

Process.new = function(cmd, args, options)
  local self = setmetatable({}, { __index = Process })
  options = options or {}
  self.cmd = cmd
  self.args = args
  self.stdin = Pipe.new()
  self.stdout = Pipe.new()
  self.stderr = Pipe.new()
  self.cwd = options.cwd
  return self
end

function Process:run(callback)
  local handle, err
  handle, err = uv.spawn(self.cmd, {
    args = self.args,
    cwd = self.cwd,
    stdio = { self.stdin.pipe, self.stdout.pipe, self.stderr.pipe },
  }, function(code, _)
    self:pipe_close()
    handle:close()
    callback {
      is_successful = code == 0,
      code = code,
      stdout = self.stdout.output,
      stderr = self.stderr.output,
    }
  end)
  if not handle then
    self:pipe_close()
  else
    self.stdout:read_start()
    self.stderr:read_start()
  end
end

function Process:pipe_close()
    self.stdin:close()
    self.stdout:close()
    self.stderr:close()
end

return Process
