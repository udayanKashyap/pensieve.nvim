if vim.fn.has("nvim-0.9.0") ~= 1 then
	vim.api.nvim_err_writeln("Pensieve.nvim requires Neovim >= 0.9.0")
	return
end

if vim.g.loaded_pensieve then
	return
end
vim.g.loaded_pensieve = true

local ok, wk = pcall(require, "which-key")
local trouble_ok = pcall(require, "trouble")

if ok then
	local mappings = {
		{ "<leader>t", group = "tasks", icon = { icon = "", color = "green" } },
		{
			"<leader>tp",
			function()
				require("pensieve").openTaskPane()
			end,
			desc = "Open Task Pane",
		},
		{
			"<leader>tP",
			function()
				require("pensieve").openProjectTaskPane()
			end,
			desc = "Open Project Task Pane",
		},
		{
			"<leader>ta",
			function()
				require("pensieve").addTask()
			end,
			desc = "Add Task",
		},
	}
	if trouble_ok then
		table.insert(mappings, {
			"<leader>tq",
			function()
				require("pensieve.trouble").open_project()
			end,
			desc = "Open Project Tasks in Quickfix (Trouble)",
		})
	end

	wk.add(mappings)
else
	vim.keymap.set("n", "<leader>tp", function()
		require("pensieve").openTaskPane()
	end, { desc = "Open Task Pane" })
	vim.keymap.set("n", "<leader>tP", function()
		require("pensieve").openProjectTaskPane()
	end, { desc = "Open Project Task Pane" })
	vim.keymap.set("n", "<leader>ta", function()
		require("pensieve").addTask()
	end, { desc = "Add Task" })

	if trouble_ok then
		vim.keymap.set("n", "<leader>tq", function()
			require("pensieve.trouble").open_project()
		end, { desc = "Open Project Tasks in Quickfix (Trouble)" })
	end
end

vim.api.nvim_create_user_command("PensieveOpen", function()
	require("pensieve").openTaskPane()
end, { desc = "Open Pensieve Task Pane" })

vim.api.nvim_create_user_command("PensieveAdd", function()
	require("pensieve").addTask()
end, { desc = "Add Pensieve Task" })

-- Trouble integration: command and keymap (safe if trouble not installed)
vim.api.nvim_create_user_command("PensieveTrouble", function()
	local ok_trouble = pcall(require, "pensieve.trouble")
	if ok_trouble then
		require("pensieve.trouble").open_project()
	else
		vim.notify("[Pensieve] trouble.nvim integration not available", vim.log.levels.WARN)
	end
end, { desc = "Open Project Tasks in Quickfix (Trouble)" })
