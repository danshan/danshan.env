# gtest: test a command against git staged changes.
#
# example usage:
#   gtest make test
function gtest -d "test command on staged changes only"
  if test (count $argv) -eq 0
    echo "Usage: "(status -u)" command [args...]" >&2
    return 2
  end
  if git diff --cached --quiet
    echo "No staged changes to test." >&2
    return 2
  end

  # Stash working dir, keeping index changes.
  git stash push -q --keep-index --include-untracked; or return
  set -l created_stash (git rev-parse --verify refs/stash); or return

  # Run test command against index changes only.
  command $argv
  set cmdstatus $status

  # Return working dir and index to original state.
  # Note: reset + restore is required to prevent merge conflicts
  # when popping the stash.
  git reset -q
  git restore .
  set -l current_stash (git rev-parse --verify refs/stash); or return
  if test "$current_stash" != "$created_stash"
    echo "Stash stack changed while the command was running; refusing to restore automatically." >&2
    return 1
  end
  git stash pop -q --index stash@{0}; or return $status

  return $cmdstatus
end
