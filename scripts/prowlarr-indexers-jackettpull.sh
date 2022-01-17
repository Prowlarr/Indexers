#!/bin/bash
# shellcheck disable=SC2162
## Script to keep Prowlarr/Indexers up to date with Jackett/Jackett
## Created by Bakerboy448
## Requirements
### Prowlarr/Indexers git repo exists
### Jackett/Jackett git repo exists
### Set variables as needed
## Using the Script
### Run from the current directory being Prowlarr/Indexers local Repo using Git Bash `./scripts/prowlarr-indexers-jackettpull.sh`

## Enhanced Logging
case $1 in
[debug]*)
    debug=true
    echo "debug logging enabled"
    ;;
[trace]*)
    debug=true
    echo "debug logging enabled"
    trace=true
    echo "trace logging enabled"
    ;;
*)
    debug=false
    trace=false
    ;;
esac

## Variables
prowlarr_git_path="/c/Development/Code/Prowlarr_Indexers/"
prowlarr_release_branch="master"
prowlarr_remote_name="origin"
prowlarr_repo_url="https://github.com/Prowlarr/Indexers"
jackett_repo_url="https://github.com/Jackett/Jackett"
jackett_release_branch="master"
jackett_remote_name="z_Jackett"
jackett_pulls_branch="jackett-pulls"
prowlarr_commit_template="jackett indexers as of"
### Indexer Versions
v1_pattern="v1"
v2_pattern="v2"
v3_pattern="v3"
v4_pattern="v4"
## ID new Version indexers by Regex
v3_regex1="# json (engine|api|UNIT3D|Elasticsearch|rartracker)"
v3_regex2="    imdbid:\r" # Requires \r to ensure is not part of another string or condition
v4_regex1="    categorydesc:"
echo "Variables set"

## Switch to Prowlarr directory and fetch all
cd "$prowlarr_git_path" || exit
## Config Git and remotes
git config advice.statusHints false # Mute Git Hints
echo "Configured Git"
git remote set-url --add "$prowlarr_remote_name" "$prowlarr_repo_url"
git remote set-url --add "$jackett_remote_name" "$jackett_repo_url"
jackett_branch="$jackett_remote_name/$jackett_release_branch"
echo "Fetching and pruning repos"
git fetch --all --prune --progress
## Check if jackett-pulls exists (remote)
remote_pulls_check=$(git ls-remote --heads $prowlarr_remote_name "$jackett_pulls_branch")
local_pulls_check=$(git branch --list "$jackett_pulls_branch")
if [ -z "$local_pulls_check" ]; then
    local_exist=false
    echo "local [$jackett_pulls_branch] does not exist"
else
    local_exist=true
    echo "local [$jackett_pulls_branch] does exist"
fi
# Check if Remote Branch exists
if [[ -z "$remote_pulls_check" ]]; then
    ## no existing remote  branch found
    pulls_exists=false
    echo "remote [$prowlarr_remote_name/$jackett_pulls_branch] does not exist"
else
    ## existing remote branch found
    pulls_exists=true
    echo "remote [$prowlarr_remote_name/$jackett_pulls_branch] does exist"
fi

if [ "$pulls_exists" = false ]; then
    ## existing remote branch not found
    if [ "$local_exist" = true ]; then
        ## local branch exists
        ## reset on master
        echo "checking out local branch [$jackett_pulls_branch]"
        git checkout -B "$jackett_pulls_branch"
        git reset "$prowlarr_release_branch"
        echo "local [$jackett_pulls_branch] reset based on [$prowlarr_release_branch]"
        if [[ $trace = true ]]; then
            read -ep $"Reached - Finished Github Actions [LocalExistsNoRemote] | Pausing for trace debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
        fi
    else
        ## local branch does not exist
        ## create new branch from master
        git checkout -B "$jackett_pulls_branch" "$prowlarr_release_branch" --no-track
        echo "local [$jackett_pulls_branch] created from [$prowlarr_release_branch]"
        if [[ $trace = true ]]; then
            read -ep $"Reached - Finished Github Actions [NoLocalNoRemote] | Pausing for trace debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
        fi
    fi
else
    ## existing remote branch found
    echo "remote [$jackett_pulls_branch] does exist"
    if [ "$local_exist" = true ]; then
        # if local exists; reset to remote
        git checkout -B "$jackett_pulls_branch"
        git reset "$prowlarr_remote_name"/"$jackett_pulls_branch"
        echo "local [$jackett_pulls_branch] reset from [$prowlarr_remote_name/$jackett_pulls_branch]"
        if [[ $trace = true ]]; then
            read -ep $"Reached - Finished Github Actions [LocalExistsRemoteExists] | Pausing for trace debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
        fi
    else
        # else create local
        git checkout -B "$jackett_pulls_branch" "$prowlarr_remote_name"/"$jackett_pulls_branch"
        echo "local [$jackett_pulls_branch] created from [$prowlarr_remote_name/$jackett_pulls_branch]"
        if [[ $trace = true ]]; then
            read -ep $"Reached - Finished Github Actions [NoLocalRemoteExists] | Pausing for trace debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
        fi
    fi
fi
echo "Branch work complete"
echo "Reviewing Commits"
existing_message=$(git log --format=%B -n1)
existing_message_ln1=$(echo "$existing_message" | awk 'NR==1')
jackett_commit_message=$(git log --format=%B -n1 -n 10 | grep "$prowlarr_commit_template" | awk 'NR==1')
jackett_recent_commit=$(git rev-parse "$jackett_branch")
echo "most recent jackett commit is: [$jackett_recent_commit] from [$jackett_branch]"
recent_pulled_commit=$(git log -n 10 | grep "$prowlarr_commit_template" | awk 'NR==1{print $5}')
## check most recent 10 commits in case we have other commits
echo "most recent jackett commit is: [$recent_pulled_commit] from [$prowlarr_remote_name/$jackett_pulls_branch]"

if [[ $trace = true ]]; then
    read -ep $"Reached - Ready to Cherrypick | Pausing for trace debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
fi
## do nothing we are we up to date
if [[ "$jackett_recent_commit" = "$recent_pulled_commit" ]]; then
    echo "we are current with jackett; nothing to do"
    exit 0
fi

## Pull commits between our most recent pull and jackett's latest commit
commit_range=$(git log --reverse --pretty="%n%H" "$recent_pulled_commit".."$jackett_recent_commit")
commit_count=$(git rev-list --count "$recent_pulled_commit".."$jackett_recent_commit")

## Cherry pick each commit and attempt to resolve common conflicts
echo "Commit Range is: [ $commit_range ]"
echo "There are [$commit_count] commits to cherry-pick"
echo "--------------------------------------------- Beginning Cherrypicking ------------------------------"
git config merge.directoryRenames true
git config merge.verbosity 0
for pick_commit in ${commit_range}; do
    has_conflicts=$(git status --porcelain | grep "[ADRCUM]")
    if [[ -n $has_conflicts ]]; then
        echo "Error Conflicts Exist - Cannot Cherrypick"
        read -ep $"Pausing due to conflicts. Press any key to continue when resolved." -n1 -s
        echo "Continuing Cherrypicking"
    fi
    echo "cherrypicking [$pick_commit]"
    git cherry-pick --no-commit --rerere-autoupdate --allow-empty --keep-redundant-commits "$pick_commit"
    if [[ $trace = true ]]; then
        echo "cherrypicked $pick_commit"
        echo "checking conflicts"
        read -ep $"Reached - Conflict checking ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
    fi
    has_conflicts=$(git ls-files --unmerged)
    if [[ -n $has_conflicts ]]; then
        readme_conflicts=$(git diff --cached --name-only | grep "README.md")
        nonyml_conflicts=$(git diff --cached --name-only | grep "\.cs\|\.js\|\.iss\|\.html")
        yml_conflicts=$(git diff --cached --name-only | grep ".yml")
        ## Handle Common Conflicts
        echo "conflicts exist"
        if [[ -n $nonyml_conflicts ]]; then
            echo "Non-YML conflicts exist; removing cs, js, iss, html"
            if [[ $trace = true ]]; then
                read -ep $"Reached - Non-YML Conflict Remove ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
            fi
            git rm --f --q --ignore-unmatch "*.cs*"
            git rm --f --q --ignore-unmatch "*.js*"
            git rm --f --q --ignore-unmatch "*.iss*"
            git rm --f --q --ignore-unmatch "*.html*"
        fi
        if [[ -n $readme_conflicts ]]; then
            echo "README conflict exists; using Prowlarr README"
            if [[ $trace = true ]]; then
                read -ep $"Reached - README Conflict ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
            fi
            git checkout --ours "README.md"
            git add --f "README.md"
        fi
        if [[ -n $yml_conflicts ]]; then
            echo "YML conflict exists; [$yml_conflicts]"
            # handle removals first
            yml_remove=$(git status --porcelain | grep yml | grep -v "definitions/" | awk -F '[ADUMRC]{1,2} ' '{print $2}' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
            for def in $yml_remove; do
                echo "Removing non-definition yml; [$yml_remove]"
                if [[ $debug = true ]]; then
                    read -ep $"Reached - YML Conflict Remove ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                fi
                git rm --f --ignore-unmatch "$yml_remove" ## remove non-definition yml
                # check if we are still conflicted after removals
                yml_conflicts=$(git diff --cached --name-only | grep ".yml")
            done
            if [[ -n $yml_conflicts ]]; then
                yml_defs=$(git status --porcelain | grep yml | grep "definitions/")
                yml_add=$(echo "$yml_defs" | grep -v "UD" | awk -F '[ADUMRC]{1,2} ' '{print $2}' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
                yml_delete=$(echo "$yml_defs" | grep "UD" | awk -F '[ADUMRC]{1,2} ' '{print $2}' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
                # Import Jackett Definitions
                for def in $yml_add; do
                    echo "Using & Adding Jackett's definition yml; [$def]"
                    if [[ $debug = true ]]; then
                        read -ep $"Reached - Def YML Conflict Add ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                    fi
                    git checkout --theirs "$def"
                    git add --f "$def" ## Add any new yml definitions
                done
                # Remove Jackett Removals
                for def in $yml_delete; do
                    echo "Removing definitions Jackett deleted; [$def]"
                    if [[ $debug = true ]]; then
                        read -ep $"Reached - Def YML Conflict Delete ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                    fi
                    git rm --f --ignore-unmatch "$def" ## Remove any yml definitions
                done
            fi
        fi
    fi
    unset has_conflicts
    unset readme_conflicts
    unset csharp_conflicts
    unset yml_conflicts
    git config merge.directoryRenames conflict
    git config merge.verbosity 2
done
echo "--------------------------------------------- completed cherry pick actions ------------------------------"
echo "Evaluating and Reviewing Changes"

# New Indexers pulled
### Depreciated
### v1
### SupportedOld
### v2
### Supported
### v3
### v4

indexers_new=$(git diff --cached --diff-filter=A --name-only | grep ".yml" | grep "$v1_pattern\|$v2_pattern\|$v3_pattern")
# Changes Indexers pulled to older versions
v1_indexers=$(git diff --cached --name-only | grep ".yml" | grep "$v1_pattern")
move_indexers_new="$indexers_new"
depreciated_indexers="$v1_indexers"
# v2, v3, and v4 are supported
changed_supported_indexers=$(git diff --cached --diff-filter=M --name-only | grep ".yml" | grep "$v2_pattern\|$v3_pattern\|$v4_pattern")
removed_indexers=$(git diff --cached --diff-filter=D --name-only | grep ".yml")

## Move new in vSupportedOld to vSupportedNew
### v1 frozen 2021-10-13
if [[ -n $move_indexers_new ]]; then
    echo "New Indexers detected"
    for indexer in ${move_indexers_new}; do
        indexer_supported=${indexer/$v1_pattern/$v2_pattern}
        indexer_supported_new=${indexer/$v1_pattern/$v3_pattern}
        indexer_supported_new2=${indexer/$v2_pattern/$v3_pattern}
        echo "Comparing [$indexer] looking for [$v1_pattern] and [$v2_pattern] and determining if indexer is [$v2_pattern] or [$v3_pattern]"
        if [[ -f $indexer ]]; then
            if grep -Eq "$v3_regex1" "$indexer" || grep -Pq "$v3_regex2" "$indexer"; then
                # code if new
                echo "[$indexer] is [$v3_pattern]"
                if [ "$indexer" = "$indexer_supported_new" ]; then
                    moveto_indexer=$indexer_supported_new2
                else
                    moveto_indexer=$indexer_supported_new
                fi
            else
                # code if not v3
                echo "[$indexer] is [$v2_pattern]"
                moveto_indexer=$indexer_supported
            fi
            if [ "$indexer" != "$moveto_indexer" ]; then
                echo "Moving indexer old [$indexer] to new [$moveto_indexer]"
                if [[ $debug = true ]]; then
                    read -ep $"Reached [vSupportedOld to vSupportedNew] ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                fi
                mv "$indexer" "$moveto_indexer"
                git rm -f "$indexer"
                git add -f "$moveto_indexer"
            fi
        else
            echo "Doing nothing; [$indexer] already in [$moveto_indexer]"
        fi
    done
    unset indexer
    unset indexer_supported
    unset indexer_supported_new
    unset moveto_indexer
    unset pattern
fi
echo "--------------------------------------------- completed new indexers ---------------------------------------------"
## Copy new changes in vDepreciated to vSupported
### v1 depreciated 2021-10-17
if [[ -n $depreciated_indexers ]]; then
    echo "Depreciated ([$v1_pattern]) Indexers with changes detected"
    for indexer in ${depreciated_indexers}; do
        indexer_supported=${indexer/$v1_pattern/$v2_pattern}
        indexer_supported_new=${indexer/$v1_pattern/$v3_pattern}
        indexer_supported_new2=${indexer/$v2_pattern/$v3_pattern}
        echo "evaluating depreciated [$v1_pattern] [$indexer]"
        if [[ -f $indexer ]]; then
            if grep -Eq "$v3_regex1" "$indexer" || grep -Eq "$v3_regex2" "$indexer"; then
                # code if new
                echo "[$indexer] is [$v3_pattern]"
                if [ "$indexer" = "$indexer_supported_new" ]; then
                    moveto_indexer=$indexer_supported_new2
                else
                    moveto_indexer=$indexer_supported_new
                fi
            else
                # code if not v3
                echo "[$indexer] is [$v2_pattern]"
                moveto_indexer=$indexer_supported
            fi
            copyto_indexer=$moveto_indexer
            if [ "$indexer" != "$copyto_indexer" ]; then
                echo "found changes | copying to [$copyto_indexer] and resetting [$indexer]"
                if [[ $debug = true ]]; then
                    read -ep $"Reached [vDepreciated to vSupported] ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                fi
                cp "$indexer" "$copyto_indexer"
                git add "$copyto_indexer"
                git checkout @ -f "$indexer"
            fi
        fi
    done
    unset indexer
    unset indexer_supported
    unset indexer_supported_new
    unset copyto_indexer
    unset pattern
fi
echo "--------------------------------------------- completed depreciated indexers ---------------------------------------------"
## Check for changes between vSupported that are type vNew
if [[ -n $changed_supported_indexers ]]; then
    echo "Older Supported ([$v2_pattern] or [$v3_pattern]) Indexers with changes detected..."
    for indexer in ${changed_supported_indexers}; do
        indexer_supported=${indexer/$v2_pattern/$v2_pattern}
        indexer_supported_new=${indexer/$v2_pattern/$v3_pattern}
        indexer_supported_new2=${indexer/$v3_pattern/$v4_pattern}
        echo "[$indexer] is changed | evaluating for [$v3_pattern] changes"
        if [[ -f $indexer ]]; then
            if grep -Eq "$v3_regex1" "$indexer" || grep -Pq "$v3_regex2" "$indexer"; then
                # code if new
                echo "[$indexer] is changed in v3 | evaluating for [$v4_pattern] changes"
                if grep -Eq "$v4_regex1" "$indexer"; then
                    echo "[$indexer] is [$v4_pattern]"
                    moveto_indexer=$indexer_supported_new2
                else
                    echo "[$indexer] is [$v3_pattern]"
                    moveto_indexer=$indexer_supported_new
                fi
            else
                # code if not v3
                echo "[$indexer] is [$v2_pattern]"
                moveto_indexer=$indexer_supported
            fi
            copyto_indexer=$moveto_indexer
            if [ "$indexer" != "$copyto_indexer" ]; then
                echo "found changes | copying to [$copyto_indexer] and resetting [$indexer]"
                if [[ $debug = true ]]; then
                    read -ep $"Reached [vSupported is vNew] ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                fi
                cp "$indexer" "$copyto_indexer"
                git add "$copyto_indexer"
                git checkout @ -f "$indexer"
            fi
        fi
    done
    unset indexer
    unset indexer_supported
    unset indexer_supported_new
    unset copyto_indexer
    unset pattern
fi
echo "--------------------------------------------- completed changed indexers ---------------------------------------------"
## Backport V3 => V2
## Backport V4 => V3
## No backport V2 => V1 2021-10-23 per Q on discord
backport_indexers=$(git diff --cached --name-only | grep ".yml" | grep "$v3_pattern\|$v4_pattern")
if [[ -n $backport_indexers ]]; then
    for indexer in ${backport_indexers}; do
        # ToDo - switch to regex and match group conditionals or make a loop
        backport_indexer=${indexer/$v4_pattern/$v3_pattern}
        backport_indexer2=${indexer/$v3_pattern/$v2_pattern}
        backport_indexer_pattern=$v3_pattern
        backport_indexer_pattern2=$v2_pattern
        echo "looking for [$backport_indexer_pattern] indexer of [$indexer]"
        if [[ -f $backport_indexer ]]; then
            echo "Found [$backport_indexer_pattern] indexer for [$indexer] - backporting to [$backport_indexer]"
            if [[ $debug = true ]]; then
                read -ep $"Reached [backporting] ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
            fi
            git difftool --no-index "$indexer" "$backport_indexer"
            git add "$backport_indexer"
        else
            echo "looking for [$backport_indexer_pattern2] indexer of [$indexer]"
            if [[ -f $backport_indexer2 ]]; then
                echo "Found [$backport_indexer_pattern2] indexer for [$indexer] - backporting to [$backport_indexer2]"
                if [[ $debug = true ]]; then
                    read -ep $"Reached [backporting] ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                fi

                git difftool --no-index "$indexer" "$backport_indexer2"
                git add "$backport_indexer2"
            else
                echo "[$v2_pattern] nor [$v3_pattern] found for [$indexer]"
            fi
        fi
    done
    unset indexer
    unset backport_indexer
fi
echo "--------------------------------------------- completed backporting indexers ---------------------------------------------"
if [[ -n $removed_indexers ]]; then
    for indexer in ${backport_indexers}; do
        # ToDo - switch to regex and match group conditionals or make a loop
        remove_indexer1=${indexer/v\d/$v1_pattern}
        remove_indexer2=${indexer/v\d/$v2_pattern}
        remove_indexer3=${indexer/v\d/$v3_pattern}
        remove_indexer4=${indexer/v\d/$v4_pattern}
        echo "looking for previous versions of removed indexer [$indexer]"
        if [[ -f $remove_indexer1 || -f $remove_indexer2 || -f $remove_indexer3 || -f $remove_indexer4 ]]; then
            echo "found previous versions of removed indexer [$indexer]"
            rm -f "$remove_indexer1"
            git rm --f --ignore-unmatch "$remove_indexer1"
            rm -f "$remove_indexer2"
            git rm --f --ignore-unmatch "$remove_indexer2"
            rm -f "$remove_indexer3"
            git rm --f --ignore-unmatch "$remove_indexer3"
            rm -f "$remove_indexer4"
            git rm --f --ignore-unmatch "$remove_indexer4"
        fi
    done
    unset indexer
fi
echo "--------------------------------------------- completed removing indexers ---------------------------------------------"
## Wait for user interaction to handle any conflicts and review
echo "After review; the script will commit the changes."
read -ep $"Press any key to continue or [Ctrl-C] to abort.  Waiting for human review..." -n1 -s
new_commit_msg="$prowlarr_commit_template $jackett_recent_commit"
if [ $pulls_exists = true ]; then
    ## If our branch existed, we squash and amend
    if [[ $debug = true ]]; then
        echo "Existing commit message line 1 is [$existing_message_ln1]"
        echo "Jackett Commit Message is [$jackett_commit_message]"
        read -ep $"Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
    fi
    # Append if previous commit is a jackett commit
    if [ "$existing_message_ln1" = "$jackett_commit_message" ]; then
        git commit --amend -m "$new_commit_msg" -m "$existing_message"
        echo "Commit Appended - [$new_commit_msg]"
    else
        git commit -m "$new_commit_msg"
        echo "New Commit made - [$new_commit_msg]"
    fi
else
    ## new branches; new commit
    git commit -m "$new_commit_msg"
    echo "New Commit made - [$new_commit_msg]"
fi
while true; do
    read -ep $"Do you wish to Force Push with Lease [Ff] or Push to $prowlarr_remote_name [Pp]? Enter any other value to exit:" -n1 fp
    case $fp in
    [Ff]*)
        if [[ $debug = true ]]; then
            read -ep $"Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
        fi
        git push "$prowlarr_remote_name" "$jackett_pulls_branch" --force-if-includes --force-with-lease
        echo "Branch Force Pushed"
        exit 0
        ;;
    [Pp]*)
        if [[ $debug = true ]]; then
            read -ep $"Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
        fi
        git push "$prowlarr_remote_name" "$jackett_pulls_branch" --force-if-includes --force-with-lease --set-upstream
        echo "Branch Pushed"
        exit 0
        ;;
    *)
        echo "Exiting"
        exit 0
        ;;
    esac
done
