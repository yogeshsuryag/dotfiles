local transparent = vim.uv.os_uname().sysname == 'Darwin'
  or string.find(vim.uv.os_uname().sysname, 'Windows') ~= nil
  or string.find(vim.uv.os_uname().release, 'WSL') ~= nil

local function preferred_theme()
  local from_env = vim.env.DOTFILES_COLOR_THEME
  if from_env == 'tokyo-night' or from_env == 'rose-pine-moon' then
    return from_env
  end
  local root = vim.env.DOTFILES_ROOT
  if not root or root == '' then
    root = vim.fn.expand('~/.dotfiles')
  end
  local env_file = root .. '/windows-config.env'
  local handle = io.open(env_file, 'r')
  if handle then
    local content = handle:read('*a')
    handle:close()
    local value = content:match('DOTFILES_COLOR_THEME%s*=%s*"?([^%s"]+)')
    if value == 'tokyo-night' or value == 'rose-pine-moon' then
      return value
    end
  end
  return 'tokyo-night'
end

local theme = preferred_theme()

return {
  {
    'rose-pine/neovim',
    lazy = false,
    priority = 1000,
    name = 'rose-pine',
    config = function()
      if theme ~= 'rose-pine-moon' then
        return
      end
      require('rose-pine').setup({
        dark_variant = 'moon',
        dim_inactive_windows = false,
        extend_background_behind_borders = false,
        styles = {
          italic = false,
          transparency = transparent,
        },
      })

      vim.cmd('colorscheme rose-pine')

      -- Make the dimmed directory path in the Snacks picker readable
      local palette = require('rose-pine.palette')
      vim.api.nvim_set_hl(0, 'SnacksPickerDir', { fg = palette.subtle })
    end,
  },
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    name = 'tokyonight',
    config = function()
      if theme ~= 'tokyo-night' then
        return
      end
      require('tokyonight').setup({
        style = 'storm',
        transparent = transparent,
      })

      vim.cmd('colorscheme tokyonight-storm')

      -- Make the dimmed directory path in the Snacks picker readable
      local colors = require('tokyonight.colors').setup({ style = 'storm' })
      vim.api.nvim_set_hl(0, 'SnacksPickerDir', { fg = colors.comment })
    end,
  },
}
