# neofs
A file manager for neovim written in lua

![](https://user-images.githubusercontent.com/32014449/97745900-d51bc080-1ae9-11eb-9a80-199b69a357ea.png)

## Mappings

| Key           | Description                                     |
|---------------|-------------------------------------------------|
| `<CR>` or `l` | Open folder or open file in the previous window |
| `0`           | Open the CWD                                    |
| `h`           | Open the parent folder of the current path      |
| `f`           | Create a new file                               |
| `d`           | Create a new directory                          |
| `<c-r>`       | Rename current item                             |
| `<c-d>`       | Delete current item                             |
| `<m-c-d>`     | Recursively delete current item                 |
| `q`           | Quit                                            |

## Custom Mappings

If you want to have some custom mappings defined whenever the file browser is open you can set them using the `setup` function.

Each callback receives the file manager as its first argument.

To see what you can do with the file manager look at [this section](#file-manager)

```lua
local neofs = require('neofs')

neofs.setup {
  mappings = {
    ["<c-e>w"] = function(fm)
      fm.path = vim.fn.expand("~/Desktop/workspace")
      fm.refresh()
    end
  }
}
```

## Devicons

Neofs supports devicons if you set `devicons` to `true`.

```lua
local neofs = require('neofs')

neofs.setup {
  devicons = true
}
```

This requires you to have `kyazdani42/nvim-web-devicons` installed.

## File Manager

TODO: Describe API
