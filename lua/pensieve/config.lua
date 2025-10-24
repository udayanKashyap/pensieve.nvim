local M = {}

M.defaults = {
	task_file = vim.fn.expand("~/NOTES/tasks.json"),
	pane_height = 12,
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
