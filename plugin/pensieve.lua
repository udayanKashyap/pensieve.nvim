if vim.fn.has("nvim-0.9.0") ~= 1 then
	vim.api.nvim_err_writeln("Pensieve.nvim requires Neovim >= 0.9.0")
	return
end

if vim.g.loaded_pensieve then
	return
end
vim.g.loaded_pensieve = true

local ok, wk = pcall(require, "which-key")

if ok then
	wk.add({
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
	})
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
end

vim.api.nvim_create_user_command("PensieveOpen", function()
	require("pensieve").openTaskPane()
end, { desc = "Open Pensieve Task Pane" })

vim.api.nvim_create_user_command("PensieveAdd", function()
	require("pensieve").addTask()
end, { desc = "Add Pensieve Task" })
