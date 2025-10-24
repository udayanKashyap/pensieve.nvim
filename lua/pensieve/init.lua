local C = require("pensieve.config")
local U = require("pensieve.utils")
local pane = require("pensieve.pane")

local M = {}

function M.setup(opts)
	C.setup(opts)
	U.ensure_task_file()
end

M.openTaskPane = pane.open
M.toggleTaskPane = pane.toggle
M.addTask = pane.add_task
M.recent_tasks = pane.recent_tasks
M.gotoTaskSource = pane.goto_source

return M
