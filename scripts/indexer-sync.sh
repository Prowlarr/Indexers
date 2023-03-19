#!/bin/bash
# shellcheck disable=SC2162
## Script to keep Prowlarr/Indexers up to date with Jackett/Jackett
## Created by Bakerboy448
## Requirements
### Prowlarr/Indexers local git repo exists
### Set variables as needed
### Typically only prowlarr_git_path would be needed to be set
## Using the Script
### Suggested to run from the current directory being Prowlarr/Indexers local Repo using Git Bash `./scripts/prowlarr-indexers-jackettpull.sh`

if ! command -v npx &> /dev/null
then
    echo "npx could not be found. check your node installation"
    exit 1
fi

# Check if Required NPM Modules are installed
if ! npm list --depth=0 ajv-cli-servarr &> /dev/null || ! npm list --depth=0 ajv-formats &> /dev/null
then
    echo "required npm packages are missing, you should run \"npm install\""
    exit 2
fi

## Enhanced Logging
case $1 in
[debug])
    debug=true
    echo "--- debug logging enabled"
    skipupstream=false
    ;;
[trace])
    debug=true
    echo "--- debug logging enabled"
    trace=true
    echo "--- trace logging enabled"
    skipupstream=false
    ;;
[dev])
    skipupstream=true
    debug=false
    trace=false
    echo "--- skipupstream; skipping upstream Prowlarr pull, local only"
    ;;
*)
    debug=false
    trace=false
    skipupstream=false
    ;;
esac

## Variables
prowlarr_git_path="./"
prowlarr_release_branch="master"
prowlarr_remote_name="origin"
prowlarr_repo_url="https://github.com/Prowlarr/Indexers"
jackett_repo_url="https://github.com/Jackett/Jackett"
jackett_release_branch="master"
jackett_remote_name="z_Jackett"
jackett_pulls_branch="jackett-pulls"
prowlarr_commit_template="jackett indexers as of"
### Indexer Schema Versions
### v1 frozen 2021-10-13
### v2 frozen 2022-04-18
### v1 and v2 purged and moved to v3 2022-06-24
### v3 purged and frozen 2022-07-22
### v4 purged and frozen 2022-08-18
### v5 purged and frozen 2022-10-14
### v6 purged and frozen 2022-10-14
min_schema=7
max_schema=9
new_schema=$((max_schema + 1))
## Switch to Prowlarr directory and fetch all
cd "$prowlarr_git_path" || exit
## Config Git and remotes
git config advice.statusHints false # Mute Git Hints
git_remotes=$(git remote -v)
prowlarr_remote_exists=$(echo "$git_remotes" | grep "$prowlarr_remote_name")
jackett_remote_exists=$(echo "$git_remotes" | grep "$jackett_remote_name")
if [ -z "$prowlarr_remote_exists" ]; then
    git remote add "$prowlarr_remote_name" "$prowlarr_repo_url"
fi
if [ -z "$jackett_remote_exists" ]; then
    git remote add "$jackett_remote_name" "$jackett_repo_url"
fi

echo "--- Configured Git"
jackett_branch="$jackett_remote_name/$jackett_release_branch"
echo "--- Fetching and pruning repos"
git fetch --all --prune --progress
## Check if jackett-pulls exists (remote)
remote_pulls_check=$(git ls-remote --heads $prowlarr_remote_name "$jackett_pulls_branch")
local_pulls_check=$(git branch --list "$jackett_pulls_branch")
if [ -z "$local_pulls_check" ]; then
    local_exist=false
    echo "--- local [$jackett_pulls_branch] does not exist"
else
    local_exist=true
    echo "--- local [$jackett_pulls_branch] does exist"
fi
# Check if Remote Branch exists
if [ -z "$remote_pulls_check" ]; then
    ## no existing remote  branch found
    pulls_exists=false
    echo "--- remote [$prowlarr_remote_name/$jackett_pulls_branch] does not exist"
else
    ## existing remote branch found
    pulls_exists=true
    echo "--- remote [$prowlarr_remote_name/$jackett_pulls_branch] does exist"
fi

if [ "$pulls_exists" = false ]; then
    ## existing remote branch not found
    if [ "$local_exist" = true ]; then
        ## local branch exists
        ## reset on master
        if [ "$skipupstream" = true ]; then
            echo "--- [$skipupstream] skipping checking out local branch [$jackett_pulls_branch]"
            echo "--- checking out local branch [$jackett_pulls_branch]"
            git checkout -B "$jackett_pulls_branch"
        else
            git reset --hard "$prowlarr_remote_name"/"$prowlarr_release_branch"
            echo "--- local [$jackett_pulls_branch] hard reset based on [$prowlarr_remote_name/$prowlarr_release_branch]"
            if $trace; then
                read -ep $"Reached - Finished Github Actions [LocalExistsNoRemote] | Pausing for trace debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
            fi
        fi
    else
        ## local branch does not exist
        ## create new branch from master
        git checkout -B "$jackett_pulls_branch" "$prowlarr_remote_name"/"$prowlarr_release_branch" --no-track
        echo "--- local [$jackett_pulls_branch] created from [$prowlarr_remote_name/$prowlarr_release_branch]"
        if $trace; then
            read -ep $"Reached - Finished Github Actions [NoLocalNoRemote] | Pausing for trace debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
        fi
    fi
else
    ## existing remote branch found
    if [ "$local_exist" = true ]; then
        # if local exists; reset to remote
        if $skipupstream; then
            echo "--- [$skipupstream] skipping checking out local branch [$jackett_pulls_branch]"
            echo "--- checking out local branch [$jackett_pulls_branch]"
            git checkout -B "$jackett_pulls_branch"
        else
            git reset --hard "$prowlarr_remote_name"/"$jackett_pulls_branch"
            echo "--- local [$jackett_pulls_branch] hard reset based on [$prowlarr_remote_name/$prowlarr_release_branch]"
        fi
        if $trace; then
            read -ep $"Reached - Finished Github Actions [LocalExistsRemoteExists] | Pausing for trace debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
        fi
    else
        # else create local
        git checkout -B "$jackett_pulls_branch" "$prowlarr_remote_name"/"$jackett_pulls_branch"
        echo "--- local [$jackett_pulls_branch] created from [$prowlarr_remote_name/$jackett_pulls_branch]"
        if $trace; then
            read -ep $"Reached - Finished Github Actions [NoLocalRemoteExists] | Pausing for trace debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
        fi
    fi
fi
echo "--- Branch work complete"
echo "--- Reviewing Commits"
existing_message=$(git log --format=%B -n1)
existing_message_ln1=$(echo "$existing_message" | awk 'NR==1')
# require start of commit
prowlarr_commits=$(git log --format=%B -n1 -n 20 | grep "^$prowlarr_commit_template")
prowlarr_jackett_commit_message=$(echo "$prowlarr_commits" | awk 'NR==1')
jackett_recent_commit=$(git rev-parse "$jackett_branch")
echo "--- most recent Jackett commit is: [$jackett_recent_commit] from [$jackett_branch]"
# require start of commit
recent_pulled_commit=$(echo "$prowlarr_commits" | awk 'NR==1{print $5}')
## check most recent 20 commits in case we have other commits
echo "--- most recent Prowlarr jackett commit is: [$recent_pulled_commit] from [$prowlarr_remote_name/$jackett_pulls_branch]"

if $trace; then
    read -ep $"Reached - Ready to Cherrypick | Pausing for trace debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
fi
## do nothing we are we up to date
if [ "$jackett_recent_commit" = "$recent_pulled_commit" ]; then
    echo "--- we are current with jackett; nothing to do"
    exit 0
fi
## fail if empty
if [ -z "$recent_pulled_commit" ]; then
    echo "--- Error Recent Pulled Commit is empty. Failing."
    exit 3
fi

## Pull commits between our most recent pull and jackett's latest commit
commit_range=$(git log --reverse --pretty="%n%H" "$recent_pulled_commit".."$jackett_recent_commit")
commit_count=$(git rev-list --count "$recent_pulled_commit".."$jackett_recent_commit")

## Cherry pick each commit and attempt to resolve common conflicts
echo "--- Commit Range is: [ $commit_range ]"
echo "--- There are [$commit_count] commits to cherry-pick"
echo "--- --------------------------------------------- Beginning Cherrypicking ------------------------------"
git config merge.directoryRenames true
git config merge.verbosity 0
for pick_commit in ${commit_range}; do
    has_conflicts=$(git ls-files --unmerged)
    if [ -n "$has_conflicts" ]; then
        echo "--- Error Conflicts Exist [$has_conflicts] - Cannot Cherrypick"
        read -ep $"Pausing due to conflicts. Press any key to continue when resolved." -n1 -s
        echo "--- Continuing Cherrypicking"
    fi
    echo "--- cherrypicking [$pick_commit]"
    git cherry-pick --no-commit --rerere-autoupdate --allow-empty --keep-redundant-commits "$pick_commit"
    if $trace; then
        echo "--- cherrypicked $pick_commit"
        echo "--- checking conflicts"
        read -ep $"Reached - Conflict checking ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
    fi
    has_conflicts=$(git ls-files --unmerged)
    if [ -n "$has_conflicts" ]; then
        readme_conflicts=$(git diff --cached --name-only | grep "README.md")
        nonyml_conflicts=$(git diff --cached --name-only | grep "\.cs\|\.js\|\.iss\|\.html")
        yml_conflicts=$(git diff --cached --name-only | grep ".yml")
        schema_conflicts=$(git diff --cached | grep ".schema.json")
        ## Handle Common Conflicts
        echo "--- conflicts exist"
        if [ -n "$readme_conflicts" ]; then
            echo "--- README conflict exists; using Prowlarr README"
            if $trace; then
                read -ep $"Reached - README Conflict ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
            fi
            git checkout --ours "README.md"
            git add --f "README.md"
        fi
        if [ -n "$schema_conflicts" ]; then
            echo "--- Schema conflict exists; using Jackett Schema and creating version [$new_schema]"
            if $trace; then
                read -ep $"Reached - README Conflict ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
            fi
            mv "$schema_conflicts" "$prowlarr_git_path/$new_schema/schema.json"
            git checkout --theirs "*schema.json"
            git add --f "*schema.json"
        fi

        if [ -n "$nonyml_conflicts" ]; then
            echo "--- Non-YML conflicts exist; removing cs, js, iss, html"
            if $trace; then
                read -ep $"Reached - Non-YML Conflict and non Schema Remove ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
            fi
            # use our package json and package-lock
            git checkout --ours "package.json"
            git checkout --ours "package-lock.json"
            git checkout --ours ".editorconfig"
            git rm --f --q --ignore-unmatch "*.cs*"
            git rm --f --q --ignore-unmatch "src/Jackett*/**.js*"
            git rm --f --q --ignore-unmatch "*.iss*"
            git rm --f --q --ignore-unmatch "*.html*"
        fi
        if [ -n "$yml_conflicts" ]; then
            echo "--- YML conflict exists; [$yml_conflicts]"
            # handle removals first
            yml_remove=$(git status --porcelain | grep yml | grep -v "definitions/" | awk -F '[ADUMRC]{1,2} ' '{print $2}' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
            for def in $yml_remove; do
                echo "--- Removing non-definition yml; [$yml_remove]"
                if $debug; then
                    read -ep $"Reached - YML Conflict Remove ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                fi
                git rm --f --ignore-unmatch "$yml_remove" ## remove non-definition yml
                # check if we are still conflicted after removals
                yml_conflicts=$(git diff --cached --name-only | grep ".yml")
            done
            if [ -n "$yml_conflicts" ]; then
                yml_defs=$(git status --porcelain | grep yml | grep "definitions/")
                yml_add=$(echo "$yml_defs" | grep -v "UD\|D" | awk -F '[ADUMRC]{1,2} ' '{print $2}' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
                yml_delete=$(echo "$yml_defs" | grep "UD" | awk -F '[ADUMRC]{1,2} ' '{print $2}' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
                # Import Jackett Definitions
                for def in $yml_add; do
                    echo "--- Using & Adding Jackett's definition yml; [$def]"
                    if $debug; then
                        read -ep $"Reached - Def YML Conflict Add ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                    fi
                    git checkout --theirs "$def"
                    git add --f "$def" ## Add any new yml definitions
                done
                # Remove Jackett Removals
                for def in $yml_delete; do
                    echo "--- Removing definitions Jackett deleted; [$def]"
                    if $debug; then
                        read -ep $"Reached - Def YML Conflict Delete ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                    fi
                    git rm --f --ignore-unmatch "$def" ## Remove any yml definitions
                done
            fi
        fi
    fi
    git config merge.directoryRenames conflict
    git config merge.verbosity 2
done
echo "--- --------------------------------------------- completed cherry pick actions ------------------------------"
echo "--- Evaluating and Reviewing Changes"

# TODO: find a better way to ignore schema.json changes from Jackett
git checkout HEAD -- "definitions/v*/schema.json"

# New Indexers pulled
# Segment Changes
added_indexers=$(git diff --cached --diff-filter=A --name-only | grep ".yml" | grep "v[$min_schema-$max_schema]")
modified_indexers=$(git diff --cached --diff-filter=M --name-only | grep ".yml" | grep "v[$min_schema-$max_schema]")
removed_indexers=$(git diff --cached --diff-filter=D --name-only | grep ".yml" | grep "v[$min_schema-$max_schema]")
# Create new version directory just in case.
new_vers_dir="definitions/v$new_schema"
mkdir -p "$new_vers_dir"

echo "===A Added Indexers are [$added_indexers]"
echo "===M Modified Indexers are [$modified_indexers]"
echo "===R Removed Indexers are [$removed_indexers]"

# Version Functions
# Loop through Schema definitions from max to min and determine lowest matching schema of the definition file passed
function determine_best_schema_version() {
    echo "determining best schema version"
    def_file=$1
    matched_version=0
    for ((i = min_schema; i <= max_schema; i++)); do
        dir="definitions/v$i"
        schema="$dir/schema.json"
        echo "checking file [$def_file] against schema [$schema]"
        npx ajv test -d "$def_file" -s "$schema" --valid -c ajv-formats --spec=draft2019
        test_resp=$?
        if [ $test_resp -eq 0 ]; then
            echo "Definition [$def_file] matches schema [$schema]"
            matched_version=$i
            export matched_version
            break
        fi
        if [ i = $max_schema ]; then
            echo "===E ERROR - Definition [$def_file] does not match max schema [$max_schema]."
            echo "===C Cardigann update likely needed. Version [$new_schema] required Review definition."
            export matched_version
        fi
    done
}

# Loop through Schema definitions and check if valid for that version
function determine_schema_version() {
    def_file=$1
    echo "testing schema version of [$def_file]"
    check_version=$(echo "$indexer" | cut -d'/' "-f2")
    dir="definitions/$check_version"
    schema="$dir/schema.json"
    echo "checking file against schema [$schema]"
    npx ajv test -d "$def_file" -s "$schema" --valid -c ajv-formats --spec=draft2019
    test_resp=$?
    if [ $test_resp -eq 0 ]; then
        echo "Definition [$def_file] matches schema [$schema]"
    else
        check_version="v0"
    fi
    export check_version
}

if [ -n "$added_indexers" ]; then
    echo "--- New Indexers detected"
    for indexer in ${added_indexers}; do
        echo "--- Evaluating [$indexer] Cardigann Version"
        if [ -f "$indexer" ]; then
            # Get Schema Version. Returns matched_version as version number. 0 if invalid
            # If the version git pulled to passes do nothing; else identify the version
            determine_schema_version "$indexer"
            echo "--- Checked Version Output is $check_version"
            if [ $check_version != "v0" ]; then
                echo "--- Schema Test passed."
                updated_indexer=$indexer
            else
                echo "--- Schema Test failed. Attempting to determine version"
                determine_best_schema_version "$indexer"
                if [ "$matched_version" -eq 0 ]; then
                    echo "--- Version [$new_schema] required. Review definition [$indexer]"
                    v_matched="v$new_schema"
                else
                    v_matched="v$matched_version"
                fi
                updated_indexer=${indexer/v[0-9]/$v_matched}
                if [ "$indexer" != "$updated_indexer" ]; then
                    echo "--- Moving indexer old [$indexer] to new [$updated_indexer]"
                    if $debug; then
                        read -ep $"Reached [vCurrent to vLatest] ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                    fi
                    mv "$indexer" "$updated_indexer"
                    git rm -f "$indexer"
                    git add -f "$updated_indexer"
                else
                    echo "--- Doing nothing; [$indexer] already is [$updated_indexer]"
                fi
            fi
        fi
    done
    unset indexer
    unset test
fi
echo "--- --------------------------------------------- completed new indexers ---------------------------------------------"
## Check modified indexers
if [ -n "$modified_indexers" ]; then
    echo "--- Reviewing Modified Indexers..."
    for indexer in ${modified_indexers}; do
        echo "--- Evaluating [$indexer] Cardigann Version"
        if [ -f "$indexer" ]; then
            # Get Schema Version. Returns matched_version as version number. 0 if invalid
            # If the version git pulled to passes do nothing; else identify the version
            determine_schema_version "$indexer"
            echo "--- Checked Version Output is $check_version"
            if [ $check_version != "v0" ]; then
                echo "--- Schema Test passed."
                updated_indexer=$indexer
            else
                echo "--- Schema Test failed. Attempting to determine version"
                determine_best_schema_version "$indexer"
                if [ "$matched_version" -eq 0 ]; then
                    echo "--- Version [$new_schema] required. Review definition [$indexer]"
                    v_matched="v$new_schema"
                else
                    v_matched="v$matched_version"
                fi
                updated_indexer=${indexer/v[0-9]/$v_matched}
                if [ "$indexer" != "$updated_indexer" ]; then
                    echo "--- Version bumped indexer old [$indexer] to new [$updated_indexer]"
                    if $debug; then
                        read -ep $"Reached [vCurrent to vLatest] ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                    fi
                    mv "$indexer" "$updated_indexer"
                    git checkout HEAD -- "$indexer"
                    git add -f "$updated_indexer"
                else
                    echo "--- Doing nothing; [$indexer] already is [$updated_indexer]"
                fi
            fi
        fi
    done
    unset indexer
    unset test
fi
echo "--- --------------------------------------------- completed changed indexers ---------------------------------------------"
echo "--- --------------------------------------------- begining indexer backporting ---------------------------------------------"
# Get new set of modified indexers after version checking above
modified_indexers_vcheck=$(git diff --cached --diff-filter=AM --name-only | grep ".yml" | grep "v[$min_schema-$max_schema]")
# Backporting Indexers
if [ -n "$modified_indexers_vcheck" ]; then
    for indexer in ${modified_indexers_vcheck}; do
        for ((i = max_schema; i >= min_schema; i--)); do
            version="v$i"
            echo "--- looking for [$version] indexer of [$indexer]"
            indexer_check=${indexer/v[0-9]/$version}
            if [ "$indexer_check" != "$indexer" ] && [ -f "$indexer_check" ]; then
                echo "--- Found [v$i] indexer for [$indexer] - comparing to [$indexer_check]"
                if $debug; then
                    read -ep $"Reached [backporting] ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                fi
                echo "--- HUMAN! Review this change and ensure no incompatible updates are backported."
                git difftool --no-index "$indexer" "$indexer_check"
                git add "$indexer_check"
            fi
        done
    done
    unset indexer
    unset indexer_check
fi
newschema_indexers=$(git diff --cached --diff-filter=A --name-only | grep ".yml" | grep "v$new_schema")
if [ -n "$newschema_indexers" ]; then
    for indexer in ${newschema_indexers}; do
        for ((i = max_schema; i >= min_schema; i--)); do
            version="v$i"
            echo "--- looking for [$version] indexer of [$indexer]"
            indexer_check=${indexer/v[0-9]/$version}
            if [ "$indexer_check" != "$indexer" ] && [ -f "$indexer_check" ]; then
                echo "--- Found [v$i] indexer for [$indexer] - comparing to [$indexer_check]"
                if $debug; then
                    read -ep $"Reached [backporting] ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                fi
                echo "=== WARNING THIS IS A NEW CARDIGANN VERSION THAT IS REQUIRED ---"
                echo "=== HUMAN! Review this change and ensure no incompatible updates are backported. ---"
                git difftool --no-index "$indexer" "$indexer_check"
                git add "$indexer_check"
            fi
        done
    done
    unset indexer
    unset indexer_check
fi

echo "--- --------------------------------------------- completed backporting indexers ---------------------------------------------"
if [ -n "$removed_indexers" ]; then
    for indexer in ${removed_indexers}; do
        echo "--- looking for previous versions of removed indexer [$indexer]"
        for ((i = max_schema; i >= min_schema; i--)); do
            indexer_remove=${indexer/v[0-9]/v$i}
            if [ "$indexer_remove" != "$indexer" ] && [ -f "$indexer_remove" ]; then
                echo "--- Found [v$i] indexer for [$indexer] - removing [$indexer_remove]"
                if $debug; then
                    read -ep $"Reached [backporting] ; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
                fi
                rm -f "$indexer_remove"
                git rm --f --ignore-unmatch "$indexer_remove"
            fi
        done
    done
    unset indexer
    unset indexer_remove
fi
echo "--- --------------------------------------------- completed removing indexers ---------------------------------------------"

echo "===A Added Indexers are [$added_indexers]"
echo "===M Modified Indexers are [$modified_indexers]"
echo "===R Removed Indexers are [$removed_indexers]"
echo "===N New Schema Indexers are [$newschema_indexers]"

# Cleanup new version folder if unused
if [ -d "$new_vers_dir" ]; then
    if [ "$(ls -A $new_vers_dir)" ]; then
        # do nothing
        echo "--- WARNING THIS IS A NEW CARDIGANN VERSION THAT IS REQUIRED: Version [v$new_schema] is needed. ---"
        echo "--- Review the following definitions for new Cardigann Version: $newschema_indexers"
    else
        # remove new version directory
        rmdir $new_vers_dir
    fi
fi

git rm -r -f -q --ignore-unmatch --cached node_modules

## Wait for user interaction to handle any conflicts and review
echo "--- After review; the script will commit the changes."
read -ep $"Press any key to continue or [Ctrl-C] to abort.  Waiting for human review..." -n1 -s
new_commit_msg="$prowlarr_commit_template $jackett_recent_commit"
if [ $pulls_exists = true ]; then
    ## If our branch existed, we squash and amend
    if $debug; then
        echo "--- Existing commit message line 1 is [$existing_message_ln1]"
        echo "--- Jackett Commit Message is [$prowlarr_jackett_commit_message]"
        read -ep $"Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
    fi
    # Append if previous commit is a jackett commit
    if [ "$existing_message_ln1" = "$prowlarr_jackett_commit_message" ]; then
        git commit --amend -m "$new_commit_msg" -m "$existing_message"
        echo "--- Commit Appended - [$new_commit_msg]"
    else
        git commit -m "$new_commit_msg"
        echo "--- New Commit made - [$new_commit_msg]"
    fi
else
    ## new branches; new commit
    git commit -m "$new_commit_msg"
    echo "--- New Commit made - [$new_commit_msg]"
fi
while true; do
    read -ep $"Do you wish to Force Push with Lease [Ff] or Push to $prowlarr_remote_name [Pp]? Enter any other value to exit:" -n1 fp
    case $fp in
    [Ff]*)
        if $debug; then
            read -ep $"Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
        fi
        git push "$prowlarr_remote_name" "$jackett_pulls_branch" --force-if-includes --force-with-lease
        echo "--- Branch Force Pushed"
        exit 0
        ;;
    [Pp]*)
        if $debug; then
            read -ep $"Pausing for debugging - Press any key to continue or [Ctrl-C] to abort." -n1 -s
        fi
        git push "$prowlarr_remote_name" "$jackett_pulls_branch" --force-if-includes
        echo "--- Branch Pushed"
        exit 0
        ;;
    *)
        echo "--- Exiting"
        exit 0
        ;;
    esac
done
