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

  set -l temporary_root /tmp
  if set -q TMPDIR
    set temporary_root "$TMPDIR"
  end
  set -l worktree_dir (mktemp -d "$temporary_root/gtest.XXXXXX"); or return
  git worktree add --quiet --detach "$worktree_dir" HEAD; or begin
    rmdir "$worktree_dir"
    return 1
  end
  git diff --cached --binary | git -C "$worktree_dir" apply --index; or begin
    git worktree remove --force "$worktree_dir"
    return 1
  end

  pushd "$worktree_dir" >/dev/null; or return
  command $argv
  set cmdstatus $status
  popd >/dev/null
  git worktree remove --force "$worktree_dir"; or return

  return $cmdstatus
end
