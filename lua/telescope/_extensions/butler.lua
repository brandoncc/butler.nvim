local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
    error("butler.nvim requires nvim-telescope/telescope.nvim")
end

return telescope.register_extension({
    exports = {
        buffers = require("telescope._extensions.butler.buffers"),
    },
})
