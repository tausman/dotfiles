local ignore_immutable = false

function setup(config)
  config.action("toggle ignore immutable", function()
    ignore_immutable = not ignore_immutable
    if ignore_immutable then
      flash("ignore immutable is turned on")
    else
      flash("ignore immutable is turned off")
    end
  end, { key = "G", scope = "revisions" })


  config.action("revisions.rebase.apply", function()
    jjui.builtin.revisions.rebase.apply({ force = ignore_immutable })
  end)

  config.action("revisions.squash.apply", function()
    jjui.builtin.revisions.squash.apply({ force = ignore_immutable })
  end)

  config.action("revisions.edit", function()
    if ignore_immutable then
      local change_id = context.change_id()
      if change_id then
        -- Drop straight down to the raw CLI to force the edit
        jj("edit", "--ignore-immutable", change_id)
        revisions.refresh()
      else
        flash({ text = "No revision selected", error = true })
      end
    else
      -- Fall back to standard behavior when toggle is off
      jjui.builtin.revisions.edit()
    end
  end)
end
