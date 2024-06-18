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

usage() {
    echo "Usage: $0 [-r remote] [-b branch] [-m mode] [-p push_mode] [-c commit_template] [-u prowlarr_repo_url] [-j jackett_repo_url] [-R release_branch] [-J jackett_branch] [-n jackett_remote_name]"
    exit 1
}

# Default values
prowlarr_remote_name="origin"
prowlarr_target_branch="master"
mode_choice="normal"
push_mode="push"
PROWLARR_COMMIT_TEMPLATE="jackett indexers as of"
PROWLARR_REPO_URL="https://github.com/Prowlarr/Indexers.git"
JACKETT_REPO_URL="https://github.com/Jackett/Jackett.git"
PROWLARR_RELEASE_BRANCH="master"
JACKETT_BRANCH="master"
JACKETT_REMOTE_NAME="z_Jackett"
# Prowlarr Schema Versions
## v1 frozen 2021-10-13
## v2 frozen 2022-04-18
## v1 and v2 purged and moved to v3 2022-06-24
## v3 purged and frozen 2022-07-22
## v4 purged and frozen 2022-08-18
## v5 purged and frozen 2022-10-14
## v6 purged and frozen 2022-10-14
## v7 purged and frozen 2024-04-27
## v8 purged and frozen 2024-04-27
MIN_SCHEMA=9
MAX_SCHEMA=10
NEW_SCHEMA=$((MAX_SCHEMA + 1))
NEW_VERS_DIR="definitions/v$NEW_SCHEMA"
mkdir -p "$NEW_VERS_DIR"

log() {
    local level="$1"
    local message="$2"
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]|[$level]|$message"
}

determine_schema_version() {
    local def_file="$1"
    log "INFO" "Testing schema version of [$def_file]"

    check_version=$(echo "$def_file" | cut -d'/' -f2)
    dir="definitions/$check_version"
    schema="$dir/schema.json"

    log "INFO" "Checking file against schema [$schema]"
    local test_output
    npx ajv test -d "$def_file" -s "$schema" --valid -c ajv-formats --spec=draft2019
    test_output=$?

    if [ "$test_output" = 0 ]; then
        log "INFO" "Definition [$def_file] matches schema [$schema]"
    else
        check_version="v0"
    fi
    export check_version
}

determine_best_schema_version() {
    local def_file="$1"
    log "INFO" "Determining best schema version for [$def_file]"

    matched_version=0
    for ((i = MIN_SCHEMA; i <= MAX_SCHEMA; i++)); do
        dir="definitions/v$i"
        schema="$dir/schema.json"
        log "INFO" "Checking file [$def_file] against schema [$schema]"
        local test_output
        npx ajv test -d "$def_file" -s "$schema" --valid -c ajv-formats --spec=draft2019
        test_output=$?

        if [ "$test_output" = 0 ]; then
            log "INFO" "Definition [$def_file] matches schema [$schema]"
            matched_version=$i
            export matched_version
            break
        fi

        if [ $i -eq $MAX_SCHEMA ]; then
            log "WARN" "Definition [$def_file] does not match max schema [$MAX_SCHEMA]."
            log "WARN" "Cardigann update likely needed. Version [$NEW_SCHEMA] required. Review definition."
            export matched_version
        fi
    done
}

initialize_script() {
    if ! command -v npx &>/dev/null; then
        log "ERROR" "npx could not be found. check your node installation"
        exit 1
    fi

    # Check if Required NPM Modules are installed
    if ! npm list --depth=0 ajv-cli-servarr &>/dev/null || ! npm list --depth=0 ajv-formats &>/dev/null; then
        log "ERROR" "required npm packages are missing, you should run \"npm install\""
        exit 2
    fi
}

while getopts ":r:b:m:p:c:u:j:R:J:n:" opt; do
  case ${opt} in
    r )
      prowlarr_remote_name=$OPTARG
      ;;
    b )
      prowlarr_target_branch=$OPTARG
      ;;
    m )
      mode_choice=$OPTARG
      case "$mode_choice" in
        normal|n|N)
          is_dev_exec=false
          ;;
        development|d|D)
          is_dev_exec=true
          log "INFO" "Skipping upstream reset to local. Also Skip checking out the local branch and log an info message."
          log "INFO" "This will not reset branch from upstream/master and will ONLY checkout the selected branch to use."
          log "INFO" "This will pause at various debugging points for human review"
          ;;
        *)
          usage
          ;;
      esac
      ;;
    p )
      push_mode=$OPTARG
      ;;
    c )
      PROWLARR_COMMIT_TEMPLATE=$OPTARG
      ;;
    u )
      PROWLARR_REPO_URL=$OPTARG
      ;;
    j )
      JACKETT_REPO_URL=$OPTARG
      ;;
    R )
      PROWLARR_RELEASE_BRANCH=$OPTARG
      ;;
    J )
      JACKETT_BRANCH=$OPTARG
      ;;
    n )
      JACKETT_REMOTE_NAME=$OPTARG
      ;;
    \? )
      usage
      ;;
  esac
done
shift $((OPTIND -1))

configure_git() {
    git config advice.statusHints false
    git_remotes=$(git remote -v)
    prowlarr_remote_exists=$(echo "$git_remotes" | grep "$prowlarr_remote_name")
    jackett_remote_exists=$(echo "$git_remotes" | grep "$JACKETT_REMOTE_NAME")

    if [ -z "$prowlarr_remote_exists" ]; then
        git remote add "$prowlarr_remote_name" "$PROWLARR_REPO_URL"
    fi

    if [ -z "$jackett_remote_exists" ]; then
        git remote add "$JACKETT_REMOTE_NAME" "$JACKETT_REPO_URL"
    fi

    log "INFO" "Configured Git"
    git fetch --all --prune
}

check_branches() {
    local remote_pulls_check local_pulls_check

    remote_pulls_check=$(git ls-remote --heads "$prowlarr_remote_name" "$prowlarr_target_branch")
    local_pulls_check=$(git branch --list "$prowlarr_target_branch")

    if [ -z "$local_pulls_check" ]; then
        local_exist=false
        log "INFO" "local branch [$prowlarr_target_branch] does not exist"
    else
        local_exist=true
        log "INFO" "local branch [$prowlarr_target_branch] does exist"
    fi

    if [ -z "$remote_pulls_check" ]; then
        pulls_exists=false
        log "INFO" "remote repo/branch [$prowlarr_remote_name/$prowlarr_target_branch] does not exist"
    else
        pulls_exists=true
        log "INFO" "remote repo/branch [$prowlarr_remote_name/$prowlarr_target_branch] does exist"
    fi
}

handle_branch_reset() {
    if [ "$pulls_exists" = false ]; then
        if [ "$local_exist" = true ]; then
            if [ "$is_dev_exec" = true ]; then
                log "INFO" "[$is_dev_exec] skipping reset to [$prowlarr_remote_name/$PROWLARR_RELEASE_BRANCH] and checking out local branch [$prowlarr_target_branch]"
                git checkout -B "$prowlarr_target_branch"
            else
                git reset --hard "$prowlarr_remote_name"/"$PROWLARR_RELEASE_BRANCH"
                log "INFO" "local [$prowlarr_target_branch] hard reset based on remote/branch [$prowlarr_remote_name/$PROWLARR_RELEASE_BRANCH]"
            fi
        else
            git checkout -B "$prowlarr_target_branch" "$prowlarr_remote_name"/"$PROWLARR_RELEASE_BRANCH" --no-track
            log "INFO" "local [$prowlarr_target_branch] created from remote/branch [$prowlarr_remote_name/$PROWLARR_RELEASE_BRANCH]"
        fi
    else
        if [ "$local_exist" = true ]; then
            if $is_dev_exec; then
                git checkout -B "$prowlarr_target_branch"
                log "INFO" "Checked out out local branch [$prowlarr_target_branch]"
                log "DEBUG" "Development Mode - Skipping reset to upstream/master"
            else
                git reset --hard "$prowlarr_remote_name"/"$prowlarr_target_branch"
                log "INFO" "local [$prowlarr_target_branch] hard reset based on [$prowlarr_remote_name/$PROWLARR_RELEASE_BRANCH]"
            fi
        else
            git checkout -B "$prowlarr_target_branch" "$prowlarr_remote_name"/"$prowlarr_target_branch"
            log "INFO" "local [$prowlarr_target_branch] created from [$prowlarr_remote_name/$prowlarr_target_branch]"
        fi
    fi
}

commit_and_push() {
    log "INFO" "Reviewing Commits"
    existing_message=$(git log --format=%B -n1)
    existing_message_ln1=$(echo "$existing_message" | awk 'NR==1')
    prowlarr_commits=$(git log --format=%B -n1 -n 20 | grep "^$PROWLARR_COMMIT_TEMPLATE")
    prowlarr_jackett_commit_message=$(echo "$prowlarr_commits" | awk 'NR==1')
    if [ "$is_dev_exec" = true ]; then
        log "DEBUG" "Jackett Remote is [$JACKETT_REMOTE_NAME/$JACKETT_BRANCH]"
        # read -r -p "Pausing to review commits. Press any key to continue." -n1 -s
    fi
    jackett_recent_commit=$(git rev-parse "$JACKETT_REMOTE_NAME/$JACKETT_BRANCH")
    log "INFO" "most recent Jackett commit is: [$jackett_recent_commit] from [$JACKETT_REMOTE_NAME/$JACKETT_BRANCH]"
    recent_pulled_commit=$(echo "$prowlarr_commits" | awk 'NR==1{print $5}')
    log "INFO" "most recent Prowlarr jackett commit is: [$recent_pulled_commit] from [$prowlarr_remote_name/$prowlarr_target_branch]"

    if [ "$jackett_recent_commit" = "$recent_pulled_commit" ]; then
        log "INFO" "we are current with jackett; nothing to do"
        exit 0
    fi

    if [ -z "$recent_pulled_commit" ]; then
        log "ERROR" "Recent Pulled Commit is empty. Failing."
        exit 3
    fi

    # Define the command to get the commit range
    commit_range_cmd="git log --reverse --pretty='%n%H' $recent_pulled_commit..$jackett_recent_commit"
    # Execute the command and capture the output
    commit_range=$(eval "$commit_range_cmd")
    commit_count=$(git rev-list --count "$recent_pulled_commit".."$jackett_recent_commit")
    log "INFO" "There are [$commit_count] commits to cherry-pick"
    if [ "$is_dev_exec" = true ]; then
        log "DEBUG" "Get Range Command is [$commit_range_cmd]"
        # read -r -p "Pausing to review commits. Press any key to continue." -n1 -s
    fi
    log "INFO" "Commit Range is: [$commit_range]"
    log "INFO" "Beginning Cherrypicking"
    git config merge.directoryRenames true
    git config merge.verbosity 0

    for pick_commit in ${commit_range}; do
        has_conflicts=$(git ls-files --unmerged)
        if [ -n "$has_conflicts" ]; then
            log "ERROR" "Conflicts Exist [$has_conflicts] - Cannot Cherrypick"
            read -r -p "Pausing due to conflicts. Press any key to continue when resolved." -n1 -s
            log "INFO" "Continuing Cherrypicking"
        fi
        log "INFO" "cherrypicking [$pick_commit]"
        git cherry-pick --no-commit --rerere-autoupdate --allow-empty --keep-redundant-commits "$pick_commit"
        has_conflicts=$(git ls-files --unmerged)
        if [ -n "$has_conflicts" ]; then
            resolve_conflicts
        fi
        git config merge.directoryRenames conflict
        git config merge.verbosity 2
    done

    log "INFO" "completed cherry pick actions"
    log "INFO" "Evaluating and Reviewing Changes"

    git checkout HEAD -- "definitions/v*/schema.json"

    handle_new_indexers
    handle_modified_indexers
    handle_backporting_indexers

    cleanup_and_commit
    push_changes
}

resolve_conflicts() {
    readme_conflicts=$(git diff --cached --name-only | grep "README.md")
    nonyml_conflicts=$(git diff --cached --name-only | grep "\.cs\|\.js\|\.iss\|\.html")
    yml_conflicts=$(git diff --cached --name-only | grep ".yml")
    schema_conflicts=$(git diff --cached --name-only | grep ".schema.json")

    log "INFO" "conflicts exist"
    if [ -n "$readme_conflicts" ]; then
        log "INFO" "README conflict exists; using Prowlarr README"
        git checkout --ours "README.md"
        git add --f "README.md"
    fi
    if [ -n "$schema_conflicts" ]; then
        log "INFO" "Schema conflict exists; using Prowlarr schema"
        git checkout --ours "*schema.json"
        git add --f "*schema.json"
    fi

    if [ -n "$nonyml_conflicts" ]; then
        log "INFO" "Non-YML conflicts exist; removing cs, js, iss, html"
        git rm --f --q --ignore-unmatch "*.cs*"
        git rm --f --q --ignore-unmatch "*.js"
        git rm --f --q --ignore-unmatch "*.iss*"
        git rm --f --q --ignore-unmatch "*.html*"
        git checkout --ours "package.json"
        git checkout --ours "package-lock.json"
        git checkout --ours ".editorconfig"
    fi
    if [ -n "$yml_conflicts" ]; then
        log "INFO" "YML conflict exists; [$yml_conflicts]"
        handle_yml_conflicts
    fi
}

handle_yml_conflicts() {
    yml_remove=$(git status --porcelain | grep yml | grep -v "definitions/" | awk -F '[ADUMRC]{1,2} ' '{print $2}' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
    for def in $yml_remove; do
        log "INFO" "Removing non-definition yml; [$yml_remove]"
        git rm --f --ignore-unmatch "$yml_remove"
        yml_conflicts=$(git diff --cached --name-only | grep ".yml")
    done
    if [ -n "$yml_conflicts" ]; then
        yml_defs=$(git status --porcelain | grep yml | grep "definitions/")
        yml_add=$(echo "$yml_defs" | grep -v "UD\|D" | awk -F '[ADUMRC]{1,2} ' '{print $2}' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
        yml_delete=$(echo "$yml_defs" | grep "UD" | awk -F '[ADUMRC]{1,2} ' '{print $2}' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')

        for def in $yml_add; do
            log "INFO" "Using & Adding Jackett's definition yml; [$def]"
            git checkout --theirs "$def"
            git add --f "$def"
        done
        for def in $yml_delete; do
            log "INFO" "Removing definitions Jackett deleted; [$def]"
            git rm --f --ignore-unmatch "$def"
        done
    fi
}

handle_new_indexers() {
    added_indexers=$(git diff --cached --diff-filter=A --name-only | grep ".yml" | grep -E "v[[:digit:]]+")
    if [ -n "$added_indexers" ]; then
        log "INFO" "New Indexers detected"
        for indexer in ${added_indexers}; do
            log "INFO" "Evaluating [$indexer] Cardigann Version"
            if [ -f "$indexer" ]; then
                determine_schema_version "$indexer"
                log "INFO" "Checked Version Output is $check_version"
                if [ "$check_version" != "v0" ]; then
                    log "INFO" "Schema Test passed."
                    updated_indexer=$indexer
                else
                    determine_best_schema_version "$indexer"
                    if [ "$matched_version" -eq 0 ]; then
                        log "INFO" "Version [$NEW_SCHEMA] required. Review definition [$indexer]"
                        v_matched="v$NEW_SCHEMA"
                    else
                        v_matched="v$matched_version"
                    fi
                    updated_indexer=${indexer/v[0-9]*/$v_matched}
                    if [ "$indexer" != "$updated_indexer" ]; then
                        log "INFO" "Moving indexer old [$indexer] to new [$updated_indexer]"
                        mv "$indexer" "$updated_indexer"
                        git rm -f "$indexer"
                        git add -f "$updated_indexer"
                    else
                        log "INFO" "Doing nothing; [$indexer] already is [$updated_indexer]"
                    fi
                fi
            fi
        done
        unset indexer
        unset test
    fi
    log "INFO" "completed new indexers"
}

handle_modified_indexers() {
    modified_indexers=$(git diff --cached --diff-filter=M --name-only | grep ".yml" | grep -E "v[[:digit:]]+")
    if [ -n "$modified_indexers" ]; then
        log "INFO" "Reviewing Modified Indexers..."
        for indexer in ${modified_indexers}; do
            log "INFO" "Evaluating [$indexer] Cardigann Version"
            if [ -f "$indexer" ]; then
                determine_schema_version "$indexer"
                log "INFO" "Checked Version Output is $check_version"
                if [ "$check_version" != "v0" ]; then
                    log "INFO" "Schema Test passed."
                    updated_indexer=$indexer
                else
                    determine_best_schema_version "$indexer"
                    if [ "$matched_version" -eq 0 ]; then
                        log "INFO" "Version [$NEW_SCHEMA] required. Review definition [$indexer]"
                        v_matched="v$NEW_SCHEMA"
                    else
                        v_matched="v$matched_version"
                    fi
                    updated_indexer=${indexer/v[0-9]*/$v_matched}
                    if [ "$indexer" != "$updated_indexer" ]; then
                        log "INFO" "Version bumped indexer old [$indexer] to new [$updated_indexer]"
                        mv "$indexer" "$updated_indexer"
                        git checkout HEAD -- "$indexer"
                        git add -f "$updated_indexer"
                    else
                        log "INFO" "Doing nothing; [$indexer] already is [$updated_indexer]"
                    fi
                fi
            fi
        done
        unset indexer
        unset test
    fi
    log "INFO" "completed changed indexers"
}

handle_backporting_indexers() {
    modified_indexers_vcheck=$(git diff --cached --diff-filter=AM --name-only | grep ".yml" | grep -E "v[[:digit:]]+")
    if [ -n "$modified_indexers_vcheck" ]; then
        for indexer in ${modified_indexers_vcheck}; do
            # SC2004: $/${} is unnecessary on arithmetic variables.
            for ((i = MAX_SCHEMA; i >= MIN_SCHEMA; i--)); do
                version="v$i"
                log "INFO" "looking for [$version] indexer of [$indexer]"
                indexer_check=$(echo "$indexer" | sed -E "s/v[0-9]+/$version/")
                if [ "$indexer_check" != "$indexer" ] && [ -f "$indexer_check" ]; then
                    log "INFO" "Found [v$i] indexer for [$indexer] - comparing to [$indexer_check]"
                    log "INFO" "HUMAN! Review this change and ensure no incompatible updates are backported."
                    git difftool --no-index "$indexer" "$indexer_check"
                    git add "$indexer_check"
                fi
            done
        done
        unset indexer
        unset indexer_check
    fi

    newschema_indexers=$(git diff --cached --diff-filter=A --name-only | grep ".yml" | grep "v$NEW_SCHEMA")
    if [ -n "$newschema_indexers" ]; then
        for indexer in ${newschema_indexers}; do
            # SC2004: $/${} is unnecessary on arithmetic variables.
            for ((i = MAX_SCHEMA; i >= MIN_SCHEMA; i--)); do
                version="v$i"
                log "INFO" "looking for [$version] indexer of [$indexer]"
                indexer_check=$(echo "$indexer" | sed -E "s/v[0-9]+/$version/")
                if [ "$indexer_check" != "$indexer" ] && [ -f "$indexer_check" ]; then
                    log "INFO" "Found [v$i] indexer for [$indexer] - comparing to [$indexer_check]"
                    log "WARNING" "THIS IS A NEW CARDIGANN VERSION THAT IS REQUIRED"
                    log "INFO" "HUMAN! Review this change and ensure no incompatible updates are backported."
                    git difftool --no-index "$indexer" "$indexer_check"
                    git add "$indexer_check"
                fi
            done
        done
        unset indexer
        unset indexer_check
    fi
    log "INFO" "completed backporting indexers"
}

cleanup_and_commit() {
    if [ -n "$removed_indexers" ]; then
        for indexer in ${removed_indexers}; do
            log "INFO" "looking for previous versions of removed indexer [$indexer]"
            # SC2004: $/${} is unnecessary on arithmetic variables.
            for ((i = MAX_SCHEMA; i >= MIN_SCHEMA; i--)); do
                indexer_remove=$(echo "$indexer" | sed -E "s/v[0-9]+/$version/")
                if [ "$indexer_remove" != "$indexer" ] && [ -f "$indexer_remove" ]; then
                    log "INFO" "Found [v$i] indexer for [$indexer] - removing [$indexer_remove]"
                    rm -f "$indexer_remove"
                    git rm --f --ignore-unmatch "$indexer_remove"
                fi
            done
        done
        unset indexer
        unset indexer_remove
    fi

    log "INFO" "Added Indexers are [$added_indexers]"
    log "INFO" "Modified Indexers are [$modified_indexers]"
    log "INFO" "Removed Indexers are [$removed_indexers]"
    log "INFO" "New Schema Indexers are [$newschema_indexers]"

    if [ -d "$NEW_VERS_DIR" ]; then
        if [ "$(ls -A $NEW_VERS_DIR)" ]; then
            log "WARNING" "THIS IS A NEW CARDIGANN VERSION THAT IS REQUIRED: Version [v$NEW_SCHEMA] is needed."
            log "INFO" "Review the following definitions for new Cardigann Version: $newschema_indexers"
        else
            rmdir $NEW_VERS_DIR
        fi
    fi

    git rm -r -f -q --ignore-unmatch --cached node_modules

    log "INFO" "After review; the script will commit the changes."
    read -r -p "Press any key to continue or [Ctrl-C] to abort. Waiting for human review..." -n1 -s
    new_commit_msg="$PROWLARR_COMMIT_TEMPLATE $jackett_recent_commit [$(date -u +'%Y-%m-%dT%H:%M:%SZ')]"

    if [ "$pulls_exists" = true ] && [ "$prowlarr_target_branch" != "$PROWLARR_RELEASE_BRANCH" ]; then
        if [ "$existing_message_ln1" = "$prowlarr_jackett_commit_message" ]; then
            git commit --amend -m "$new_commit_msg" -m "$existing_message"
            log "INFO" "Commit Appended - [$new_commit_msg]"
        else
            git commit -m "$new_commit_msg"
            log "INFO" "New Commit made - [$new_commit_msg]"
        fi
    else
        git commit -m "$new_commit_msg"
        log "INFO" "New Commit made - [$new_commit_msg]"
    fi
}

push_changes() {
    push_branch="$prowlarr_target_branch"
    case "$push_mode" in
    force)
        git push "$prowlarr_remote_name" "$push_branch" --force-if-includes --force-with-lease
        log "INFO" "Branch Force Pushed"
        ;;
    push)
        git push "$prowlarr_remote_name" "$push_branch" --force-if-includes
        log "INFO" "Branch Pushed"
        ;;
    *)
        log "INFO" "Invalid push mode specified. Exiting."
        exit 1
        ;;
    esac
}

main() {
    initialize_script
    configure_git
    check_branches
    handle_branch_reset
    commit_and_push
    push_changes
}

main "$@"
