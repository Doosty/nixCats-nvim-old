local categories = require('nixCats')
local servers = {}
if (categories.neonixdev) then
  require('neodev').setup({})
  -- this allows our thing to have plugin library detection
  -- despite not being in our .config/nvim folder
  -- I learned about it here:
  -- https://github.com/lecoqjacob/nixCats-nvim/blob/main/.neoconf.json
  require("neoconf").setup({
    plugins = {
      lua_ls = {
        enabled = true,
        enabled_for_neovim_config = true,
      },
    },
  })

  servers.lua_ls = {
    Lua = {
      formatters = {
        ignoreComments = true,
      },
      signatureHelp = { enabled = true },
    },
    workspace = { checkThirdParty = true },
    telemetry = { enabled = false },
    filetypes = { 'lua' },
  }

  servers.nixd = {}
  servers.nil_ls = {}

end
if (categories.lspDebugMode) then
  vim.lsp.set_log_level("debug")
end

-- This is this flake's version of what kickstarter has set up for mason handlers.
-- This is a convenience function that calls lspconfig on the lsps we downloaded via nix
-- This will not download your lsp. Nix does that.

--  Add any additional override configuration in the following tables. They will be passed to
--  the `settings` field of the server config. You must look up that documentation yourself.
--  All of them are listed in https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
--
--  If you want to override the default filetypes that your language server will attach to you can
--  define the property 'filetypes' to the map in question.
--  You may do the same thing with cmd

-- servers.clangd = {},
-- servers.gopls = {},
-- servers.pyright = {},
-- servers.rust_analyzer = {},
-- servers.tsserver = {},
-- servers.html = { filetypes = { 'html', 'twig', 'hbs'} },

for server_name,_ in pairs(servers) do
  require('lspconfig')[server_name].setup({
    capabilities = require('myLuaConf.LSPs.caps-onattach').get_capabilities(),
    on_attach = require('myLuaConf.LSPs.caps-onattach').on_attach,
    settings = servers[server_name],
    filetypes = (servers[server_name] or {}).filetypes,
    cmd = (servers[server_name] or {}).cmd,
    root_pattern = (servers[server_name] or {}).root_pattern,
  })
end
