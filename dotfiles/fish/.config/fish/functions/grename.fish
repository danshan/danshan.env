function grename -d "Rename 'old' branch to 'new', including in origin remote" -a old new
  if test (count $argv) -ne 2
    echo "Usage: "(status -u)" old_branch new_branch"
    return 1
  end
  git branch -m $old $new; or return
  git push --set-upstream origin $new; or begin
    git branch -m $new $old
    return 1
  end
  git push origin --delete $old
end

complete -c grename -x -a "(complete -C 'git branch ')"
