local C = require("pensieve.config")

local U = {}

--- Ensure the task file and directory exist.
function U.ensure_task_file()
	local dir = vim.fn.fnamemodify(C.options.task_file, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end
	if vim.fn.filereadable(C.options.task_file) == 0 then
		vim.fn.writefile({ "[]" }, C.options.task_file)
	end
end

--- Read tasks from JSON file.
---@return table
function U.read_tasks()
	if vim.fn.filereadable(C.options.task_file) == 0 then
		return {}
	end
	local content = table.concat(vim.fn.readfile(C.options.task_file), "\n")
	local ok, data = pcall(vim.json.decode, content)
	if not ok or type(data) ~= "table" then
		vim.notify("[Pensieve] Failed to parse JSON", vim.log.levels.ERROR)
		return {}
	end
	return data
end

--- Write tasks to JSON file.
---@param tasks table
function U.write_tasks(tasks)
	local ok, encoded = pcall(vim.json.encode, tasks)
	if not ok then
		vim.notify("[Pensieve] Failed to encode JSON", vim.log.levels.ERROR)
		return
	end
	vim.fn.writefile(vim.split(encoded, "\n"), C.options.task_file)
end

--- Detect current project (git root or cwd).
---@return string, string project_name, project_root
function U.detect_project()
	local ok, out = pcall(vim.fn.systemlist, "git rev-parse --show-toplevel")
	if ok and out and #out > 0 and out[1] ~= "" then
		return vim.fn.fnamemodify(out[1], ":t"), out[1]
	end
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t"), vim.fn.getcwd()
end

return U
