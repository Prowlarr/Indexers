#!/bin/sh

## Script to keep Prowlarr/Indexers up to date with Jackett/Jackett
## Requirements
### Prowlarr/Indexers git repo exists
### Jackett/Jackett git repo exists

## Variables
prowlarr_git_path="/c/Development/Code/Prowlarr_Indexers/"
jackett_repo_name="z_Jackett/master"
jackett_pulls_branch="jackett-pulls"
prowlarr_commit_template="jackett indexers as of "

## Switch to Prowlarr directory and fetch all
cd "$prowlarr_git_path" || exit
git fetch --all

## Check if jackett-pulls exists
pulls_check=$(git ls-remote --heads origin "$jackett_pulls_branch")
if [ -z "$pulls_check" ]; then
    ## no existing branch found
    pulls_exists=false
    echo "origin/$jackett_pulls_branch does not exist"
    git checkout -b "$jackett_pulls_branch" - origin/master
    echo "origin/$jackett_pulls_branch created from master"
## create new branch from master
else
    ## existing branch found
    pulls_exists=true
    echo "origin/$jackett_pulls_branch does exist"
    git checkout "$jackett_pulls_branch"
    echo "origin/$jackett_pulls_branch checked out from origin"
    existing_message=$(git log --format=%B -n1)
## pull down recently
fi

jackett_recent_commit=$(git rev-parse "$jackett_repo_name")
echo "most recent jackett commit is: $jackett_recent_commit"
recent_pulled_commit=$(git log -n 10 | grep "$prowlarr_commit_template" | awk 'NR==1{print $5}')
## check most recent 10 commits in case we have other commits
echo "most recent origin jackett pulled commit is: $recent_pulled_commit"
## cherry pick our most recent to our last
git cherry-pick --no-commit "$recent_pulled_commit".."$jackett_recent_commit"

## Handle some common conflicts
### Remove all C# files; we don't care about these
git rm "*.cs"
### we only want our read me
git checkout --ours ./README.md
git add "README.md"
## Add any new yml definitions
git add "*.yml"
## Wait for user interaction to handle any conflicts and review
echo "Don't forget to backport any new indexer version changes to the oldest supported Prowlarr version"
echo "After review; the script will commit the changes (disabled:and push)"
echo "Press any key to continue.  Waiting for human review..."
pause
new_commit_msg="$prowlarr_commit_template $jackett_recent_commit"
if [ $pulls_exists ]; then
    ## If our branch existed, we squash and ammend
    git merge --squash
    git commit --amend -m "$new_commit_msg" -m "$existing_message"
    #disabled git push origin $jackett_pulls_branch --force
else
    ## new branches; new commit
    git commit -m "$new_commit_msg"
    #disabled git push origin $jackett_pulls_branch
fi
