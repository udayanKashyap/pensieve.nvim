local C = require("pensieve.config")
local U = require("pensieve.utils")

local M = {}

local pane = {
	buf = nil,
	win = nil,
	prev_win = nil,
	line_map = {},
	kind = "all", -- all | project
}

-- namespace for highlights
local ns = vim.api.nvim_create_namespace("pensieve_ns")

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------
local function ensure_buf_valid()
	return pane.buf and vim.api.nvim_buf_is_valid(pane.buf)
end

local function rebuild_pane()
	if not ensure_buf_valid() then
		return
	end

	vim.api.nvim_set_hl(0, "PensieveDoneIcon", { fg = "#b8db87", bold = true })
	vim.api.nvim_set_hl(
		0,
		"PensieveDoneDesc",
		{ fg = vim.api.nvim_get_hl(0, { name = "Comment" }).fg, strikethrough = true }
	)
	vim.api.nvim_set_hl(0, "PensieveDesc", { link = "Normal" })
	vim.api.nvim_set_hl(0, "PensieveProject", { link = "Directory" })
	vim.api.nvim_set_hl(0, "PensieveFile", { link = "Comment" })

	local icon_unchecked = "󰄱 "
	local icon_checked = "󰄲 "

	local tasks = U.read_tasks()
	local display = {}
	pane.line_map = {}

	-- Build ordered indices: first incomplete (in fetch order), then completed (in fetch order)
	local ordered_indices = {}
	for i, t in ipairs(tasks) do
		if not t.done then
			table.insert(ordered_indices, i)
		end
	end
	for i, t in ipairs(tasks) do
		if t.done then
			table.insert(ordered_indices, i)
		end
	end

	-- Build display lines following the ordered indices and maintain line_map -> original index
	for line_no, idx in ipairs(ordered_indices) do
		local t = tasks[idx]
		local icon = t.done and icon_checked or icon_unchecked
		local filename = (t.file and t.file:match("([^/]+)$")) or t.file or "[NoFile]"
		local line = ""
		if t.project and t.project ~= "" then
			line = string.format("- %s  %s      %s -%s", icon, t.desc, t.project, filename)
		else
			line = string.format("- %s  %s  %s", icon, t.desc, filename)
		end
		table.insert(display, line)
		pane.line_map[line_no] = idx
	end

	if #display == 0 then
		display = { "-- No tasks -- (a to add)" }
	end

	vim.bo[pane.buf].modifiable = true
	vim.api.nvim_buf_set_lines(pane.buf, 0, -1, false, display)
	vim.bo[pane.buf].modifiable = false

	vim.api.nvim_buf_clear_namespace(pane.buf, ns, 0, -1)

	-- Apply highlights aligned with the visual order using line_map
	for line_no = 1, #display do
		local idx = pane.line_map[line_no]
		local t = tasks[idx]
		local line = line_no - 1

		local icon_hl = t.done and "PensieveDoneIcon" or ""
		local icon_start = 2
		local icon_end = icon_start + #icon_unchecked

		vim.api.nvim_buf_set_extmark(pane.buf, ns, line, icon_start, {
			end_col = icon_end,
			hl_group = icon_hl,
		})

		if t.project and t.project ~= "" then
			local project_marker = " "
			local project_pos = string.find(display[line_no], project_marker, 1, true)
			if project_pos then
				local project_start = project_pos - 1
				local project_end = project_pos + #t.project + 4
				vim.api.nvim_buf_set_extmark(pane.buf, ns, line, project_start, {
					end_col = project_end,
					hl_group = "PensieveProject",
					priority = 1,
				})

				local file_pos = string.find(display[line_no], "-", project_end, true)
				if file_pos then
					vim.api.nvim_buf_set_extmark(pane.buf, ns, line, file_pos - 1, {
						end_col = #display[line_no],
						hl_group = "PensieveFile",
						priority = 1,
					})
				end
			end
		else
			local file_pos = string.find(display[line_no], t.desc, 1, true)
			if file_pos then
				vim.api.nvim_buf_set_extmark(pane.buf, ns, line, file_pos + #t.desc + 2, {
					end_col = #display[line_no],
					hl_group = "PensieveFile",
					priority = 1,
				})
			end
		end

		if t.done then
			vim.api.nvim_buf_set_extmark(pane.buf, ns, line, 8, {
				end_col = #display[line_no],
				hl_group = "PensieveDoneDesc",
				priority = 5,
			})
		end
	end
end

-- forward declaration for project-only rebuild
local rebuild_project_pane

function M.refresh()
	if pane.kind == "project" then
		rebuild_project_pane()
	else
		rebuild_pane()
	end
end

-----------------------------------------------------------------------
-- Pane Lifecycle
-----------------------------------------------------------------------
function M.open()
	if pane.win and vim.api.nvim_win_is_valid(pane.win) then
		vim.api.nvim_set_current_win(pane.win)
		-- switch to all-tasks view if needed
		pane.kind = "all"
		rebuild_pane()
		return
	end

	pane.prev_win = vim.api.nvim_get_current_win()
	pane.buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(pane.buf, "PensievePane")

	vim.bo[pane.buf].buftype = "nofile"
	vim.bo[pane.buf].bufhidden = "wipe"
	vim.bo[pane.buf].swapfile = false
	vim.bo[pane.buf].modifiable = false
	vim.bo[pane.buf].filetype = "pensieve"

	vim.cmd("botright " .. C.options.pane_height .. "split")
	pane.win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(pane.win, pane.buf)
	vim.wo[pane.win].number = false
	vim.wo[pane.win].relativenumber = false

	local function bmap(mode, lhs, rhs, desc)
		vim.keymap.set(mode, lhs, rhs, { buffer = pane.buf, silent = true, desc = desc })
	end

	bmap("n", "q", M.close, "Close pane")
	bmap("n", "r", M.refresh, "Refresh tasks")
	bmap("n", "a", M.add_task, "Add task")
	bmap("n", "<CR>", M.goto_source, "Goto source")
	bmap("n", "x", M.toggle_task, "Toggle task")
	bmap("n", "dd", M.delete_task, "Delete task")

	pane.kind = "all"
	rebuild_pane()

	vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
		buffer = pane.buf,
		callback = function()
			pane.buf, pane.win, pane.line_map = nil, nil, {}
			pcall(vim.api.nvim_buf_clear_namespace, pane.buf, ns, 0, -1)
		end,
	})
end

-----------------------------------------------------------------------
-- Project-only Pane
-----------------------------------------------------------------------
-- Separate rebuild function for project-only view
function rebuild_project_pane()
	if not ensure_buf_valid() then
		return
	end

	vim.api.nvim_set_hl(0, "PensieveDoneIcon", { fg = "#b8db87", bold = true })
	vim.api.nvim_set_hl(
		0,
		"PensieveDoneDesc",
		{ fg = vim.api.nvim_get_hl(0, { name = "Comment" }).fg, strikethrough = true }
	)
	vim.api.nvim_set_hl(0, "PensieveDesc", { link = "Normal" })
	vim.api.nvim_set_hl(0, "PensieveProject", { link = "Directory" })
	vim.api.nvim_set_hl(0, "PensieveFile", { link = "Comment" })

	local icon_unchecked = "󰄱 "
	local icon_checked = "󰄲 "

	local tasks_all = U.read_tasks()
	local display = {}
	pane.line_map = {}

	local project_name, project_root = U.detect_project()

	-- filter to current project
	local filtered_indices = {}
	for i, t in ipairs(tasks_all) do
		local belongs = false
		if t.project_root and project_root then
			belongs = t.project_root == project_root
		elseif t.project and project_name then
			belongs = t.project == project_name
		end
		if belongs then
			table.insert(filtered_indices, i)
		end
	end

	-- Order: first incomplete, then completed (both in fetch order)
	local ordered_indices = {}
	for _, i in ipairs(filtered_indices) do
		if not tasks_all[i].done then
			table.insert(ordered_indices, i)
		end
	end
	for _, i in ipairs(filtered_indices) do
		if tasks_all[i].done then
			table.insert(ordered_indices, i)
		end
	end

	for line_no, idx in ipairs(ordered_indices) do
		local t = tasks_all[idx]
		local icon = t.done and icon_checked or icon_unchecked
		local filename = (t.file and t.file:match("([^/]+)$")) or t.file or "[NoFile]"
		local line = ""
		if t.project and t.project ~= "" then
			line = string.format("- %s  %s      %s -%s", icon, t.desc, t.project, filename)
		else
			line = string.format("- %s  %s  %s", icon, t.desc, filename)
		end
		table.insert(display, line)
		pane.line_map[line_no] = idx -- map to original index in tasks_all
	end

	if #display == 0 then
		display = { "-- No tasks for this project -- (a to add)" }
	end

	vim.bo[pane.buf].modifiable = true
	vim.api.nvim_buf_set_lines(pane.buf, 0, -1, false, display)
	vim.bo[pane.buf].modifiable = false

	vim.api.nvim_buf_clear_namespace(pane.buf, ns, 0, -1)

	-- Highlights identical to all-tasks view
	for line_no = 1, #display do
		local idx = pane.line_map[line_no]
		local t = tasks_all[idx]
		local line = line_no - 1

		local icon_hl = t.done and "PensieveDoneIcon" or ""
		local icon_start = 2
		local icon_end = icon_start + #icon_unchecked

		vim.api.nvim_buf_set_extmark(pane.buf, ns, line, icon_start, {
			end_col = icon_end,
			hl_group = icon_hl,
		})

		if t.project and t.project ~= "" then
			local project_marker = " "
			local project_pos = string.find(display[line_no], project_marker, 1, true)
			if project_pos then
				local project_start = project_pos - 1
				local project_end = project_pos + #t.project + 4
				vim.api.nvim_buf_set_extmark(pane.buf, ns, line, project_start, {
					end_col = project_end,
					hl_group = "PensieveProject",
					priority = 1,
				})

				local file_pos = string.find(display[line_no], "-", project_end, true)
				if file_pos then
					vim.api.nvim_buf_set_extmark(pane.buf, ns, line, file_pos - 1, {
						end_col = #display[line_no],
						hl_group = "PensieveFile",
						priority = 1,
					})
				end
			end
		else
			local file_pos = string.find(display[line_no], t.desc, 1, true)
			if file_pos then
				vim.api.nvim_buf_set_extmark(pane.buf, ns, line, file_pos + #t.desc + 2, {
					end_col = #display[line_no],
					hl_group = "PensieveFile",
					priority = 1,
				})
			end
		end

		if t.done then
			vim.api.nvim_buf_set_extmark(pane.buf, ns, line, 8, {
				end_col = #display[line_no],
				hl_group = "PensieveDoneDesc",
				priority = 5,
			})
		end
	end
end

function M.open_project()
	if pane.win and vim.api.nvim_win_is_valid(pane.win) then
		vim.api.nvim_set_current_win(pane.win)
		pane.kind = "project"
		rebuild_project_pane()
		return
	end

	pane.prev_win = vim.api.nvim_get_current_win()
	pane.buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(pane.buf, "PensievePane")

	vim.bo[pane.buf].buftype = "nofile"
	vim.bo[pane.buf].bufhidden = "wipe"
	vim.bo[pane.buf].swapfile = false
	vim.bo[pane.buf].modifiable = false
	vim.bo[pane.buf].filetype = "pensieve"

	vim.cmd("botright " .. C.options.pane_height .. "split")
	pane.win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(pane.win, pane.buf)
	vim.wo[pane.win].number = false
	vim.wo[pane.win].relativenumber = false

	local function bmap(mode, lhs, rhs, desc)
		vim.keymap.set(mode, lhs, rhs, { buffer = pane.buf, silent = true, desc = desc })
	end

	bmap("n", "q", M.close, "Close pane")
	bmap("n", "r", M.refresh, "Refresh tasks")
	bmap("n", "a", M.add_task, "Add task")
	bmap("n", "<CR>", M.goto_source, "Goto source")
	bmap("n", "x", M.toggle_task, "Toggle task")
	bmap("n", "dd", M.delete_task, "Delete task")

	pane.kind = "project"
	rebuild_project_pane()

	vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
		buffer = pane.buf,
		callback = function()
			pane.buf, pane.win, pane.line_map = nil, nil, {}
			pcall(vim.api.nvim_buf_clear_namespace, pane.buf, ns, 0, -1)
		end,
	})
end

function M.close()
	if pane.win and vim.api.nvim_win_is_valid(pane.win) then
		vim.api.nvim_win_close(pane.win, true)
	end
	pane.win, pane.buf, pane.line_map = nil, nil, {}
end

function M.toggle()
	if pane.win and vim.api.nvim_win_is_valid(pane.win) then
		M.close()
	else
		M.open()
	end
end

-----------------------------------------------------------------------
-- Add / Modify Tasks
-----------------------------------------------------------------------
function M.add_task(desc)
	local origin_win = vim.api.nvim_get_current_win()
	local origin_buf = vim.api.nvim_win_get_buf(origin_win)
	local file_name = vim.api.nvim_buf_get_name(origin_buf)
	if file_name == "" then
		file_name = "[NoFile]"
	end

	local line_num = vim.api.nvim_win_get_cursor(origin_win)[1]
	local project_name, project_root = U.detect_project()

	local function append(text)
		if not text or text == "" then
			return
		end
		local tasks = U.read_tasks()
		table.insert(tasks, 1, {
			desc = text,
			done = false,
			file = file_name,
			line = line_num,
			project = project_name,
			project_root = project_root,
			created_at = os.time(),
		})
		U.write_tasks(tasks)
		vim.notify("Added: " .. text, vim.log.levels.INFO)
		rebuild_pane()
	end

	if desc then
		append(desc)
	else
		if vim.ui and vim.ui.input then
			vim.ui.input({ prompt = "New Task: " }, append)
		else
			append(vim.fn.input("New Task: "))
		end
	end
end

function M.toggle_task()
	local lnum = vim.api.nvim_win_get_cursor(pane.win)[1]
	local idx = pane.line_map[lnum]
	local tasks = U.read_tasks()
	local t = tasks[idx]
	if not t then
		return
	end
	t.done = not t.done
	U.write_tasks(tasks)
	if pane.kind == "project" then
		rebuild_project_pane()
	else
		rebuild_pane()
	end
end

function M.delete_task()
	local lnum = vim.api.nvim_win_get_cursor(pane.win)[1]
	local idx = pane.line_map[lnum]
	local tasks = U.read_tasks()
	table.remove(tasks, idx)
	U.write_tasks(tasks)
	if pane.kind == "project" then
		rebuild_project_pane()
	else
		rebuild_pane()
	end
	vim.notify("Task deleted", vim.log.levels.INFO)
end

-----------------------------------------------------------------------
-- Navigation
-----------------------------------------------------------------------
function M.goto_source()
	local lnum = vim.api.nvim_win_get_cursor(pane.win)[1]
	local idx = pane.line_map[lnum]
	local t = U.read_tasks()[idx]
	if not t then
		return
	end

	if t.project_root and vim.fn.isdirectory(t.project_root) == 1 then
		pcall(vim.cmd, "tcd " .. vim.fn.fnameescape(t.project_root))
	end

	if t.file and t.file ~= "[NoFile]" then
		-- Prefer opening the file in the window that opened the pane (pane.prev_win)
		local target_win = nil
		if pane.prev_win and vim.api.nvim_win_is_valid(pane.prev_win) then
			target_win = pane.prev_win
		end

		if target_win then
			-- Set the target window and open the file there, then set cursor in that window
			pcall(vim.api.nvim_set_current_win, target_win)
			pcall(vim.cmd, "edit " .. vim.fn.fnameescape(t.file))
			pcall(vim.api.nvim_win_set_cursor, target_win, { tonumber(t.line), 0 })
		else
			-- Fallback: open in current window
			pcall(vim.cmd, "edit " .. vim.fn.fnameescape(t.file))
			pcall(vim.api.nvim_win_set_cursor, 0, { tonumber(t.line), 0 })
		end
	else
		vim.notify("No source location found", vim.log.levels.WARN)
	end
end

-----------------------------------------------------------------------
-- Recent Tasks (for dashboards)
-----------------------------------------------------------------------
function M.recent_tasks(opts)
	opts = opts or {}
	local limit = opts.limit or 5
	local all = U.read_tasks()
	local tasks = {}

	for i, t in ipairs(all) do
		local filename = t.file and (t.file:match("([^/]+)$") or t.file) or "[NoFile]"
		table.insert(tasks, {
			key = tostring(i),
			text = {
				{ string.format("%d - ", i), hl = "SnacksDashboardKey" },
				{ string.format("%s\t", t.desc), hl = "SnacksDashboardDesc" },
				{ string.format("/%s:%d", filename, t.line), hl = "SnacksDashboardDir", align = "right" },
			},
			action = function()
				if t.project_root and vim.fn.isdirectory(t.project_root) == 1 then
					pcall(vim.cmd, "tcd " .. vim.fn.fnameescape(t.project_root))
				end
				vim.cmd("edit " .. vim.fn.fnameescape(t.file))
				pcall(vim.api.nvim_win_set_cursor, 0, { tonumber(t.line), 0 })
			end,
		})
	end

	if #tasks > limit then
		tasks = { unpack(tasks, #tasks - limit + 1, #tasks) }
	end

	return tasks
end

return M
