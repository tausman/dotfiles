return {
    "mfussenegger/nvim-dap",
    dependencies = {
        "rcarriga/nvim-dap-ui",
        "leoluz/nvim-dap-go",
        "nvim-neotest/nvim-nio",
    },
    config = function()
        local dap = require("dap")
        local dapui = require("dapui")
        local dapgo = require("dap-go")

        dapui.setup()
        dapgo.setup()

        dap.listeners.before.attach.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.launch.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated.dapui_config = function()
            dapui.close()
        end
        dap.listeners.before.event_exited.dapui_config = function()
            dapui.close()
        end

        vim.keymap.set("n", "<Leader>dt", dap.toggle_breakpoint, {})
        vim.keymap.set("n", "<Leader>dgt", dapgo.debug_test, {})
        vim.keymap.set("n", "<Leader>dc", dap.continue, {})
        vim.keymap.set("n", "<Leader>dn", dap.step_over, {})
        vim.keymap.set("n", "<Leader>di", dap.step_into, {})
        vim.keymap.set("n", "<Leader>db", dap.step_back, {})
        vim.keymap.set("n", "<Leader>do", dap.step_out, {})
        vim.keymap.set("n", "<Leader>dx", dap.terminate, {})
        vim.keymap.set("n", "<Leader>dr", dap.restart, {})
        vim.keymap.set("n", "<Leader>dl", dap.run_last, {})
        vim.keymap.set('n', '<Leader>de', function() require('dap').repl.open() end)

        -- dap.adapters.go = {
        --     type = "executable",
        --     command = "node",
        --     args = { os.getenv("HOME") .. "/dev/golang/vscode-go/extension/dist/debugAdapter.js" },
        -- }
        -- dap.configurations.go = {
        --     {
        --         type = "go",
        --         name = "Debug",
        --         request = "launch",
        --         showLog = false,
        --         program = "${file}",
        --         dlvToolPath = vim.fn.exepath("dlv"),
        --     },
        -- }
    end,
}
