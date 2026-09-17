-- taskwarrior_linear: Taskwarrior ↔ Linear ↔ Obsidian bridge commands.
-- Wraps the `taskwarrior_linear` CLI (~/.local/bin/taskwarrior_linear).
--
--   :LinearIssues  — telescope picker over my open Linear issues
--                    <CR> import to taskwarrior   <C-o> open in browser
--   :LinearProjects   — picker over open projects; <CR> imports its issues
--   :LinearMilestones — picker over open milestones; <CR> imports umbrella
--                       task + its issues; <C-o> opens in browser
--   :TWTasks       — telescope picker over pending tasks
--                    <CR> open task note          <C-o> open Linear issue (or note)
--   :TWHere        — same picker, filtered to tasks whose work dirs
--                    (workdirs.toml) cover the current directory
--   :TWNote        — same as :TWTasks <CR>
--   <leader>tt     — toggle taskwarrior-tui terminal

local M = {}

local CLI = "taskwarrior_linear"

local function run(cmd)
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("[taskwarrior_linear] " .. out:gsub("%s+$", ""), vim.log.levels.ERROR)
    return nil
  end
  return out
end

local function json_run(cmd)
  local out = run(cmd)
  if not out or out:match("^%s*$") then
    return {}
  end
  local ok, data = pcall(vim.json.decode, out)
  if not ok then
    vim.notify("[taskwarrior_linear] bad JSON from: " .. cmd, vim.log.levels.ERROR)
    return {}
  end
  return data
end

-- vim.json.decode maps JSON null to vim.NIL — a TRUTHY userdata value.
-- `x or fallback` therefore keeps vim.NIL and later blows up on #, :sub,
-- arithmetic, or concat. Never use `or` on decoded fields; check the type.
local function jstr(v, fallback)
  return type(v) == "string" and v or (fallback or "")
end

local function jnum(v)
  return tonumber(v) or 0
end

local function pick(entries, opts)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  opts = opts or {}
  pickers
    .new({}, {
      prompt_title = opts.title,
      finder = finders.new_table({
        results = entries,
        entry_maker = opts.entry_maker,
      }),
      sorter = conf.generic_sorter({}),
      previewer = opts.previewer,
      attach_mappings = function(_, map)
        map("i", "<CR>", opts.cr)
        map("n", "<CR>", opts.cr)
        if opts.ctrl_o then
          map("i", "<C-o>", opts.ctrl_o)
          map("n", "<C-o>", opts.ctrl_o)
        end
        return true
      end,
    })
    :find()
end

local function current_entry(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  return action_state.get_selected_entry()
end

local function close_and(prompt_bufnr, fn)
  local actions = require("telescope.actions")
  actions.close(prompt_bufnr)
  vim.schedule(fn)
end

-- :LinearIssues ------------------------------------------------------------

function M.linear_issues()
  local issues = json_run(CLI .. " issues --json")
  if #issues == 0 then
    vim.notify("no open Linear issues assigned to you")
    return
  end

  local previewers = require("telescope.previewers")
  local previewer = previewers.new_buffer_previewer({
    title = "Issue",
    define_preview = function(self, entry)
      local i = entry.value
      local lines = {
        i.title,
        "",
        "identifier: " .. i.identifier,
        "state:      " .. (type(i.state) == "table" and i.state.name or "?"),
        "team:       " .. (type(i.team) == "table" and i.team.key or "-"),
        "project:    " .. (type(i.project) == "table" and i.project.name or "-"),
        "due:        " .. jstr(i.dueDate):sub(1, 10),
        "",
        jstr(i.description, jstr(i.url)),
      }
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    end,
  })

  pick(issues, {
    title = "Linear — my issues",
    entry_maker = function(i)
      local due = jstr(i.dueDate):sub(1, 10)
      if due == "" then
        due = "          "
      end
      return {
        value = i,
        display = string.format(
          "%-12s %-14s %s  %s",
          i.identifier,
          type(i.state) == "table" and i.state.name or "?",
          due,
          i.title
        ),
        ordinal = i.identifier .. " " .. i.title,
      }
    end,
    previewer = previewer,
    cr = function(prompt_bufnr)
      local entry = current_entry(prompt_bufnr)
      close_and(prompt_bufnr, function()
        local out = run(string.format("%s import %s", CLI, entry.value.identifier))
        if out then
          vim.notify((out:gsub("%s+$", "")))
        end
      end)
    end,
    ctrl_o = function(prompt_bufnr)
      local entry = current_entry(prompt_bufnr)
      close_and(prompt_bufnr, function()
        vim.ui.open(entry.value.url)
      end)
    end,
  })
end

-- :LinearProjects / :LinearMilestones ---------------------------------------

-- Optional `term` runs Linear's server-side name filter before the picker;
-- the picker's own fuzzy matching still applies on top.
function M.linear_projects(term)
  term = term or ""
  local cmd = CLI .. " projects --json"
  if term and term ~= "" then
    cmd = cmd .. " --search " .. vim.fn.shellescape(term)
  end
  local projects = json_run(cmd)
  if #projects == 0 then
    vim.notify("no open Linear projects" .. (term ~= "" and (" matching " .. term) or ""))
    return
  end
  pick(projects, {
    title = "Linear — projects" .. (term ~= "" and (" · " .. term) or ""),
    entry_maker = function(p)
      local due = jstr(p.targetDate):sub(1, 10)
      if due == "" then
        due = "          "
      end
      return {
        value = p,
        display = string.format(
          "%-14s %-8s %s  %3d of %-3d  %s",
          p.slugId,
          jstr(p.state),
          due,
          math.floor(jnum(p.progress) * jnum(p.scope) + 0.5),
          jnum(p.scope),
          p.name
        ),
        ordinal = p.slugId .. " " .. p.name .. " " .. jstr(p.lead),
      }
    end,
    cr = function(prompt_bufnr)
      local entry = current_entry(prompt_bufnr)
      close_and(prompt_bufnr, function()
        local out = run(string.format("%s import-project %s", CLI, entry.value.slugId))
        if out then
          vim.notify((out:gsub("%s+$", "")))
        end
      end)
    end,
    ctrl_o = function(prompt_bufnr)
      local entry = current_entry(prompt_bufnr)
      close_and(prompt_bufnr, function()
        vim.ui.open(entry.value.url)
      end)
    end,
  })
end

function M.linear_milestones()
  local milestones = json_run(CLI .. " milestones --json")
  if #milestones == 0 then
    vim.notify("no open Linear milestones")
    return
  end
  pick(milestones, {
    title = "Linear — milestones",
    entry_maker = function(m)
      local due = jstr(m.targetDate):sub(1, 10)
      if due == "" then
        due = "          "
      end
      local pct = math.floor(math.min(jnum(m.progress), 1.0) * 100 + 0.5)
      return {
        value = m,
        display = string.format(
          "%-8s %-10s %s  %3d%%  %s — %s",
          m.id:sub(1, 8),
          jstr(m.status),
          due,
          pct,
          m.project.name,
          m.name
        ),
        ordinal = m.project.name .. " " .. m.name,
      }
    end,
    cr = function(prompt_bufnr)
      local entry = current_entry(prompt_bufnr)
      close_and(prompt_bufnr, function()
        local out = run(string.format("%s import-milestone %s", CLI, entry.value.id))
        if out then
          vim.notify((out:gsub("%s+$", "")))
        end
      end)
    end,
    ctrl_o = function(prompt_bufnr)
      local entry = current_entry(prompt_bufnr)
      close_and(prompt_bufnr, function()
        vim.ui.open(entry.value.url)
      end)
    end,
  })
end

-- :TWTasks / :TWNote --------------------------------------------------------

-- NOTE: no `rc.xxx=...` overrides here — taskwarrior prints
-- "Configuration override ..." to stderr, vim.fn.system merges stderr into
-- the output, and the JSON no longer parses. Plain export needs no overrides.
local function pending_tasks()
  return json_run("task status:pending export")
end

local function task_entry_maker(t)
  local linear = jstr(t.linear)
  -- ⇢ = waits on other tasks (issue-task with local subtasks, or a
  -- project/milestone umbrella). Subtasks and plain tasks show no marker.
  -- depends may be null (vim.NIL — truthy userdata), so check the type.
  local waits = (type(t.depends) == "table" and #t.depends > 0) and " ⇢ " or "   "
  return {
    value = t,
    display = string.format("%4s %s%-10s %s", t.id, waits, linear, t.description),
    ordinal = string.format("%s %s %s", t.id, linear, t.description),
  }
end

local function open_task_note(t)
  local path = run(string.format("%s note %d --print", CLI, t.id))
  if not path then
    return
  end
  path = path:gsub("%s+$", "")
  -- gsub returns (string, count); as the last argument in a call Lua expands
  -- both, which once fed the count to fnameescape as a 2nd argument (E118).
  -- Assigning first truncates to the string.
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function task_picker(tasks, title)
  local previewers = require("telescope.previewers")
  local previewer = previewers.new_buffer_previewer({
    title = "Task",
    define_preview = function(self, entry)
      local t = entry.value
      local lines = {
        t.description,
        "",
        "task id:  " .. t.id,
        "uuid:     " .. t.uuid,
        "project:  " .. jstr(t.project, "-"),
        "status:   " .. jstr(t.status, "?"),
        "linear:   " .. jstr(t.linear, "-"),
        "due:      " .. (type(t.due) == "string" and t.due:sub(1, 8) or "-"),
      }
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    end,
  })

  pick(tasks, {
    title = title,
    entry_maker = task_entry_maker,
    previewer = previewer,
    cr = function(prompt_bufnr)
      local entry = current_entry(prompt_bufnr)
      close_and(prompt_bufnr, function()
        open_task_note(entry.value)
      end)
    end,
    ctrl_o = function(prompt_bufnr)
      local entry = current_entry(prompt_bufnr)
      close_and(prompt_bufnr, function()
        run(string.format("%s open %d", CLI, entry.value.id))
      end)
    end,
  })
end

function M.tw_tasks()
  local tasks = pending_tasks()
  if #tasks == 0 then
    vim.notify("no pending taskwarrior tasks")
    return
  end
  task_picker(tasks, "Taskwarrior — pending")
end

-- :TWHere — tasks whose work dirs (workdirs.toml) cover nvim's cwd
function M.tw_here()
  local tasks = json_run(CLI .. " here --json")
  if #tasks == 0 then
    vim.notify("no tasks mapped under " .. vim.fn.getcwd())
    return
  end
  task_picker(tasks, "Tasks here — " .. vim.fn.getcwd())
end

function M.tw_note()
  local tasks = pending_tasks()
  if #tasks == 0 then
    vim.notify("no pending taskwarrior tasks")
    return
  end
  pick(tasks, {
    title = "Task note",
    entry_maker = task_entry_maker,
    cr = function(prompt_bufnr)
      local entry = current_entry(prompt_bufnr)
      close_and(prompt_bufnr, function()
        open_task_note(entry.value)
      end)
    end,
  })
end

-- taskwarrior-tui toggle -----------------------------------------------------

local tui_buf = nil

function M.tui_toggle()
  if tui_buf and vim.api.nvim_buf_is_valid(tui_buf) then
    local win = vim.fn.bufwinid(tui_buf)
    if win ~= -1 then
      vim.api.nvim_win_close(win, true)
    else
      vim.cmd.botright("14split")
      vim.api.nvim_set_current_buf(tui_buf)
    end
    return
  end
  vim.cmd.botright("14split")
  vim.cmd.terminal("taskwarrior-tui")
  tui_buf = vim.api.nvim_get_current_buf()
  vim.bo[tui_buf].bufhidden = "hide"
  vim.cmd.startinsert()
end

-- setup ----------------------------------------------------------------------

function M.setup(opts)
  opts = opts or {}
  local cli = opts.cli or CLI
  CLI = cli

  vim.api.nvim_create_user_command("LinearIssues", M.linear_issues, {})
  vim.api.nvim_create_user_command("LinearProjects", function(opts)
    M.linear_projects(opts.args)
  end, { nargs = "?" })
  vim.api.nvim_create_user_command("LinearMilestones", M.linear_milestones, {})
  vim.api.nvim_create_user_command("TWTasks", M.tw_tasks, {})
  vim.api.nvim_create_user_command("TWHere", M.tw_here, {})
  vim.api.nvim_create_user_command("TWNote", M.tw_note, {})
  vim.keymap.set("n", "<leader>tt", M.tui_toggle, { desc = "taskwarrior-tui" })
  vim.keymap.set("n", "<leader>tn", M.tw_tasks, { desc = "taskwarrior tasks" })
  vim.keymap.set("n", "<leader>th", M.tw_here, { desc = "tasks for this directory" })
end

return M
