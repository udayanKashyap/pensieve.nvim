local U = require("pensieve.utils")

local M = {}

-- Convert a pensieve task into a quickfix item
local function to_qf_item(t)
	if type(t) ~= "table" then
		return nil
	end
	local file = t.file or t.path or t.filename
	if not file or file == "" or file == "[NoFile]" then
		return nil
	end
	local lnum = tonumber(t.line or t.lnum) or 1
	local col = tonumber(t.col or t.column) or 1
	local text = t.desc or t.title or t.text or "Task"

	return {
		filename = vim.fn.fnamemodify(file, ":p"),
		lnum = lnum,
		col = col,
		text = text,
	}
end

local function open_trouble_quickfix()
	local ok, trouble = pcall(require, "trouble")
	if not ok then
		vim.notify("[Pensieve] trouble.nvim not found", vim.log.levels.WARN)
		return
	end
	-- Support Trouble v3 and older API styles
	local opened = pcall(function()
		trouble.open({ mode = "quickfix" })
	end)
	if not opened then
		if type(trouble.open) == "function" then
			trouble.open("quickfix")
		else
			vim.cmd("Trouble quickfix")
		end
	end
end

--- Open current project's tasks in Trouble (quickfix mode)
function M.open_project()
	local tasks = U.read_tasks()
	local project_name, project_root = U.detect_project()

	-- Filter to current project
	local filtered = {}
	for _, t in ipairs(tasks) do
		local belongs = false
		if t.project_root and project_root then
			belongs = t.project_root == project_root
		elseif t.project and project_name then
			belongs = t.project == project_name
		end
		if belongs then
			table.insert(filtered, t)
		end
	end

	if #filtered == 0 then
		vim.notify("[Pensieve] No tasks for this project", vim.log.levels.INFO)
	end

	-- Order: incomplete first, then completed (stable)
	local ordered = {}
	for _, t in ipairs(filtered) do
		if not t.done then
			table.insert(ordered, t)
		end
	end
	for _, t in ipairs(filtered) do
		if t.done then
			table.insert(ordered, t)
		end
	end

	local items = {}
	for _, t in ipairs(ordered) do
		local qf = to_qf_item(t)
		if qf then
			table.insert(items, qf)
		end
	end

	vim.fn.setqflist({}, " ", { title = "Pensieve Project Tasks", items = items })
	open_trouble_quickfix()
end

--- Open all tasks (across projects) in Trouble
function M.open_all()
	local tasks = U.read_tasks()

	-- Order: incomplete first, then completed (stable)
	local ordered = {}
	for _, t in ipairs(tasks) do
		if not t.done then
			table.insert(ordered, t)
		end
	end
	for _, t in ipairs(tasks) do
		if t.done then
			table.insert(ordered, t)
		end
	end

	local items = {}
	for _, t in ipairs(ordered) do
		local qf = to_qf_item(t)
		if qf then
			table.insert(items, qf)
		end
	end

	vim.fn.setqflist({}, " ", { title = "Pensieve Tasks", items = items })
	open_trouble_quickfix()
end

return M
