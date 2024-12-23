#!/usr/bin/env python3

import argparse
import datetime
import fnmatch
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List, Optional

# Third-party libs
import git                    # GitPython
from github import Github     # PyGitHub
import yaml
from jsonschema import validate, ValidationError

##############################################################################
#                           Global Defaults
##############################################################################

PROWLARR_REMOTE_NAME = "origin"
PROWLARR_TARGET_BRANCH = "master"
MODE_CHOICE = "normal"  # "normal" | "dev" | "jackett"

PUSH_MODE = False
PUSH_MODE_FORCE = False

PROWLARR_COMMIT_TEMPLATE = "jackett indexers as of"
PROWLARR_COMMIT_TEMPLATE_APPEND = ""
PROWLARR_REPO_URL = "https://github.com/Prowlarr/Indexers.git"
JACKETT_REPO_URL = "https://github.com/Jackett/Jackett.git"
PROWLARR_RELEASE_BRANCH = "master"
JACKETT_BRANCH = "master"
JACKETT_REMOTE_NAME = "z_Jackett"
SKIP_BACKPORT = False
IS_DEV_EXEC = False
IS_JACKETT_DEV = False

MAX_COMMITS_TO_PICK = 50

# Enhanced blocklist with wildcard patterns
BLOCKLIST_PATTERNS = [
    "uniongang*",
    "sharewood.yml",
    "ygg-api.yml",
    "anirena.yml",
    "torrentgalaxy.yml",
]

# JSON schema version constraints
MIN_SCHEMA = 10
MAX_SCHEMA = 11
NEW_SCHEMA = MAX_SCHEMA + 1
NEW_VERS_DIR = f"definitions/v{NEW_SCHEMA}"

##############################################################################
#                           Logging Setup
##############################################################################

logger = logging.getLogger("IndexerSync")
logger.setLevel(logging.DEBUG)

ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
formatter = logging.Formatter(
    "%(asctime)s|%(levelname)s|%(message)s", datefmt="%Y-%m-%dT%H:%M:%S"
)
ch.setFormatter(formatter)
logger.addHandler(ch)

##############################################################################
#             Git + GitHub: Cloning, Branching, Pull Requests
##############################################################################

def clone_or_open_repo(url: str, local_dir: str) -> git.Repo:
    """
    Clone the repo from 'url' into 'local_dir' if not already cloned.
    If 'local_dir' exists, open it as a Repo.
    Returns a GitPython 'Repo' object.
    """
    path_obj = Path(local_dir).resolve()
    if path_obj.exists() and (path_obj / ".git").is_dir():
        logger.info(f"Opening existing repo at {path_obj}")
        repo = git.Repo(str(path_obj))
    else:
        logger.info(f"Cloning {url} into {path_obj}")
        repo = git.Repo.clone_from(url, str(path_obj))
    return repo


def ensure_remote(repo: git.Repo, remote_name: str, remote_url: str):
    """
    If 'remote_name' does not exist in repo, add it with 'remote_url'.
    """
    if remote_name not in [r.name for r in repo.remotes]:
        logger.info(f"Adding remote {remote_name} => {remote_url}")
        repo.create_remote(remote_name, remote_url)


def checkout_or_create_branch(repo: git.Repo, branch_name: str, base_ref: Optional[str] = None, force_reset: bool = False):
    """
    - If the branch already exists locally, check it out.
    - Otherwise create it (optionally from base_ref).
    - If force_reset=True, do a 'reset --hard base_ref' after checkout.
    """
    if branch_name in repo.heads:
        # Branch exists locally
        logger.info(f"Branch {branch_name} already exists locally; checking it out.")
        local_branch = repo.heads[branch_name]
    else:
        # create local branch
        if base_ref:
            logger.info(f"Creating local branch {branch_name} from {base_ref}.")
            local_branch = repo.create_head(branch_name, base_ref)
        else:
            logger.info(f"Creating local branch {branch_name} from HEAD.")
            local_branch = repo.create_head(branch_name)

    # Checkout
    local_branch.checkout()

    if force_reset and base_ref:
        logger.warning(f"Hard resetting branch {branch_name} to {base_ref}...")
        repo.git.reset("--hard", base_ref)


def fetch_all_remotes(repo: git.Repo):
    """
    Equivalent to "git fetch --all --prune".
    """
    for r in repo.remotes:
        logger.debug(f"Fetching from remote {r.name}...")
        r.fetch(prune=True)


def push_branch(repo: git.Repo, branch_name: str, force_with_lease: bool = False):
    """
    Push a branch to 'origin' (or whatever remote you'd like).
    """
    remote = repo.remotes[PROWLARR_REMOTE_NAME]
    refspec = f"{branch_name}:{branch_name}"
    logger.info(f"Pushing {branch_name} to {remote.name} (refspec: {refspec})")
    push_args = [refspec]
    if force_with_lease:
        push_args.append("--force-with-lease")
    remote.push(*push_args)


def create_pull_request(
    token: str,
    repo_name: str,
    base_branch: str,
    head_branch: str,
    title: str,
    body: str,
):
    """
    Create a pull request in GitHub from 'head_branch' into 'base_branch'.
    'repo_name' is "owner/repo".
    """
    logger.info(f"Creating Pull Request: base={base_branch} <- head={head_branch} in {repo_name}")
    g = Github(token)
    gh_repo = g.get_repo(repo_name)
    pr = gh_repo.create_pull(
        title=title,
        body=body,
        head=head_branch,  # if same repo: just the branch name; if fork: "YourUser:branch"
        base=base_branch
    )
    logger.info(f"Pull Request created: {pr.html_url}")
    return pr

##############################################################################
#                     YAML + JSON Schema Validation
##############################################################################

def load_schema(schema_path: str) -> dict:
    if not os.path.exists(schema_path):
        return {}
    try:
        import json
        with open(schema_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Could not load JSON schema {schema_path}: {e}")
        return {}

def validate_definition_yml(def_file: str, schema_path: str) -> bool:
    if not os.path.exists(def_file):
        return False

    schema = load_schema(schema_path)
    if not schema:
        return False

    try:
        with open(def_file, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)
        validate(instance=data, schema=schema)
        return True
    except (ValidationError, yaml.YAMLError) as e:
        logger.debug(f"Validation failed for {def_file}: {e}")
        return False
    except Exception as e:
        logger.debug(f"Unexpected error: {def_file}: {e}")
        return False


def determine_schema_version(def_file: str) -> str:
    parts = def_file.split("/")
    if len(parts) < 2:
        return "v0"
    check_version = parts[1]
    schema_path = f"definitions/{check_version}/schema.json"
    if validate_definition_yml(def_file, schema_path):
        logger.info(f"Definition [{def_file}] matches schema [{schema_path}]")
        return check_version
    return "v0"


def determine_best_schema_version(def_file: str) -> int:
    matched_version = 0
    for i in range(MIN_SCHEMA, MAX_SCHEMA + 1):
        schema_path = f"definitions/v{i}/schema.json"
        if validate_definition_yml(def_file, schema_path):
            logger.info(f"Definition [{def_file}] matches schema v{i}")
            matched_version = i
    if matched_version == 0:
        logger.warning(f"Definition [{def_file}] does not match any schema <= v{MAX_SCHEMA}. Possibly needs v{NEW_SCHEMA}.")
    return matched_version

##############################################################################
#                            Blocklist Helpers
##############################################################################

def is_blocklisted(filename: str) -> bool:
    """
    Return True if 'filename' matches any of the wildcard patterns in BLOCKLIST_PATTERNS.
    """
    for pattern in BLOCKLIST_PATTERNS:
        if fnmatch.fnmatch(filename, pattern):
            return True
    return False

##############################################################################
#                     File Utilities & Conflict Handling
##############################################################################

def rename_version_in_path(path: str, new_version: str) -> str:
    parts = path.split("/")
    if len(parts) < 2:
        return path
    parts[1] = new_version
    return "/".join(parts)

def mkdir_for_file(filepath: str):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)

def get_diff_files(repo: git.Repo, diff_filter: str) -> List[str]:
    """
    Return filenames from 'git diff --cached --diff-filter=X --name-only' 
    using GitPython. That’s a bit manual, so we can do a direct call:
        repo.git.diff("--cached", "--diff-filter=X", "--name-only")
    """
    output = repo.git.diff("--cached", f"--diff-filter={diff_filter}", "--name-only")
    return [l for l in output.splitlines() if l.strip()]

def list_unmerged_files(repo: git.Repo) -> List[str]:
    """
    Return lines from 'git ls-files --unmerged' 
    """
    output = repo.git.ls_files("--unmerged")
    return [l for l in output.splitlines() if l.strip()]

def handle_conflict_resolution(repo: git.Repo):
    unmerged = list_unmerged_files(repo)
    if unmerged:
        logger.warning(f"Conflicts exist in: {unmerged}. Attempting partial resolution...")

    # We'll still rely on a couple of shell-based checks:
    conflicts_raw = repo.git.diff("--cached", "--name-only")
    all_conflicts = [f for f in conflicts_raw.splitlines() if f.strip()]

    # README => ours
    readme_conflicts = [c for c in all_conflicts if c.endswith("README.md")]
    for rmd in readme_conflicts:
        logger.debug(f"README conflict => using ours for {rmd}")
        repo.git.checkout("--ours", rmd)
        repo.git.add(rmd)

    # schema => ours
    schema_conflicts = [c for c in all_conflicts if c.endswith("schema.json")]
    for scf in schema_conflicts:
        logger.debug(f"Schema conflict => using ours for {scf}")
        repo.git.checkout("--ours", scf)
        repo.git.add(scf)

    # Non-yml => remove them
    remove_exts = (".cs", ".js", ".iss", ".html")
    nonyml_conflicts = [c for c in all_conflicts if any(ext in c for ext in remove_exts)]
    for path in nonyml_conflicts:
        logger.debug(f"Removing non-yml conflict file {path}")
        repo.git.rm("--force", "--ignore-unmatch", path)

    # YML => special logic
    # a quick re-check
    yml_conflicts = [c for c in all_conflicts if c.endswith(".yml")]
    if yml_conflicts:
        handle_yml_conflicts(repo)


def handle_yml_conflicts(repo: git.Repo):
    # Remove any .yml outside 'definitions/'
    status_porcelain = repo.git.status("--porcelain").splitlines()
    for line in status_porcelain:
        # lines might look like "RM path/to/something.yml"
        if ".yml" in line and "definitions/" not in line.lower():
            parts = line.strip().split(None, 1)
            if len(parts) == 2:
                path = parts[1].strip()
                logger.debug(f"Removing non-definition yml => {path}")
                repo.git.rm("--force", "--ignore-unmatch", path)

    # Re-check for YML conflicts in definitions
    conflicts_after = repo.git.diff("--cached", "--name-only").splitlines()
    yml_conflicts_after = [c for c in conflicts_after if c.endswith(".yml")]
    for def_file in yml_conflicts_after:
        if "definitions/" not in def_file:
            continue
        logger.debug(f"Accepting 'theirs' for {def_file}")
        if "src/Jackett.Common/Definitions/" in def_file:
            new_def = def_file.replace("src/Jackett.Common/Definitions/", f"definitions/v{MIN_SCHEMA}/")
            if new_def != def_file:
                mkdir_for_file(new_def)
                if os.path.isfile(def_file):
                    shutil.move(def_file, new_def)
                repo.git.checkout("--theirs", new_def)
                repo.git.add(new_def)
                repo.git.rm("--force", "--ignore-unmatch", def_file)
            else:
                repo.git.checkout("--theirs", def_file)
                repo.git.add(def_file)
        else:
            repo.git.checkout("--theirs", def_file)
            repo.git.add(def_file)


##############################################################################
#                Process Indexers (New, Modified, Backport)
##############################################################################

def process_indexer(repo: git.Repo, indexer_path: str):
    base_name = os.path.basename(indexer_path)
    # 1) Blocklist
    if is_blocklisted(base_name):
        logger.info(f"Removing blocklisted indexer {indexer_path}")
        repo.git.rm("--force", "--ignore-unmatch", indexer_path)
        return

    # 2) Validate / rename
    if not os.path.isfile(indexer_path):
        return  # possibly removed
    current_version = determine_schema_version(indexer_path)
    if current_version != "v0":
        logger.debug(f"Schema {current_version} passed for {indexer_path}")
    else:
        matched = determine_best_schema_version(indexer_path)
        if matched == 0:
            logger.warning(f"{indexer_path} => likely new schema v{NEW_SCHEMA} needed.")
            v_matched = f"v{NEW_SCHEMA}"
        else:
            v_matched = f"v{matched}"

        updated_path = rename_version_in_path(indexer_path, v_matched)
        if updated_path != indexer_path:
            logger.info(f"Renaming {indexer_path} => {updated_path}")
            mkdir_for_file(updated_path)
            shutil.move(indexer_path, updated_path)
            repo.git.rm("--force", "--ignore-unmatch", indexer_path)
            repo.git.add(updated_path)


def handle_new_indexers(repo: git.Repo):
    added_indexers = get_diff_files(repo, diff_filter="A")
    added_indexers = [p for p in added_indexers if p.endswith(".yml") and "definitions/" in p]
    if not added_indexers:
        return

    logger.info(f"Processing newly added indexers: {added_indexers}")
    for path in added_indexers:
        process_indexer(repo, path)


def handle_modified_indexers(repo: git.Repo):
    modified_indexers = get_diff_files(repo, diff_filter="M")
    modified_indexers = [p for p in modified_indexers if p.endswith(".yml") and "definitions/" in p]
    if not modified_indexers:
        return

    logger.info(f"Processing modified indexers: {modified_indexers}")
    for path in modified_indexers:
        process_indexer(repo, path)


def handle_backporting_indexers(repo: git.Repo):
    am_files = get_diff_files(repo, diff_filter="AM")
    candidate_indexers = [p for p in am_files if p.endswith(".yml") and "definitions/" in p]
    for indexer in candidate_indexers:
        parts = indexer.split("/")
        if len(parts) < 2:
            continue
        for i in range(MAX_SCHEMA, MIN_SCHEMA - 1, -1):
            oldpath = indexer.replace(parts[1], f"v{i}")
            if oldpath != indexer and os.path.isfile(oldpath):
                logger.info(f"Found older {oldpath} for {indexer}. Prompting difftool.")
                repo.git.difftool("--no-index", indexer, oldpath)
                repo.git.add(oldpath)

    # handle brand-new schema
    added_files = get_diff_files(repo, diff_filter="A")
    new_schema_defs = [p for p in added_files if p.endswith(".yml") and f"v{NEW_SCHEMA}" in p]
    for indexer in new_schema_defs:
        parts = indexer.split("/")
        if len(parts) < 2:
            continue
        for i in range(MAX_SCHEMA, MIN_SCHEMA - 1, -1):
            oldpath = indexer.replace(parts[1], f"v{i}")
            if oldpath != indexer and os.path.isfile(oldpath):
                logger.error("THIS IS A NEW CARDIGANN VERSION THAT IS REQUIRED.")
                logger.warning(f"Compare {indexer} => {oldpath} for possible backports.")
                repo.git.difftool("--no-index", indexer, oldpath)
                repo.git.add(oldpath)


##############################################################################
#                         Final Commit & Optional PR
##############################################################################

def cleanup_and_commit(repo: git.Repo):
    # remove empty new schema dir if no files
    if os.path.isdir(NEW_VERS_DIR):
        if not os.listdir(NEW_VERS_DIR):
            os.rmdir(NEW_VERS_DIR)
        else:
            logger.error(f"New Cardigann version v{NEW_SCHEMA} found. Check {NEW_VERS_DIR} carefully!")

    # remove node_modules
    if os.path.exists("node_modules"):
        repo.git.rm("-r", "-f", "-q", "--ignore-unmatch", "--cached", "node_modules")

    logger.warning("Please review changes via `git status` before final commit.")
    input("Press Enter to continue or Ctrl+C to abort...")

    # Attempt to parse the last pulled commit from existing log
    commit_msg = repo.git.log("--format=%B", "-n", "1")
    tokens = commit_msg.split()
    jackett_recent_commit = "<unknown>"
    if len(tokens) >= 6 and tokens[0] == "jackett" and tokens[1] == "indexers" and tokens[2] == "as" and tokens[3] == "of":
        jackett_recent_commit = tokens[5]

    new_commit_msg = (
        f"{PROWLARR_COMMIT_TEMPLATE} {jackett_recent_commit} "
        f"[{datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')}] "
        f"{PROWLARR_COMMIT_TEMPLATE_APPEND}"
    )

    # Check if anything is staged
    diff_out = repo.git.diff("--cached", "--name-only")
    if not diff_out.strip():
        logger.info("No staged changes to commit.")
        return

    # Commit
    logger.info(f"Committing with message: {new_commit_msg}")
    repo.git.commit("-m", new_commit_msg)


##############################################################################
#                             Main Program
##############################################################################

def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Indexer Sync Script with GitPython + PyGitHub.",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument("--local-repo", default="local_indexers_repo",
                        help="Local directory for the Prowlarr/Indexers clone (default: local_indexers_repo)")
    parser.add_argument("--mode", default=MODE_CHOICE,
                        help="Mode: normal|n, dev|development|d, jackett|j")
    parser.add_argument("--target-branch", default=PROWLARR_TARGET_BRANCH,
                        help="Prowlarr target branch (default: master)")
    parser.add_argument("--release-branch", default=PROWLARR_RELEASE_BRANCH,
                        help="Prowlarr release branch (default: master)")
    parser.add_argument("--push", action="store_true",
                        help="Whether to push changes after committing")
    parser.add_argument("--force-push", action="store_true",
                        help="Force push with lease")
    parser.add_argument("--skip-backport", action="store_true",
                        help="Skip backporting new definitions to older schemas")
    parser.add_argument("--jackett-branch", default=JACKETT_BRANCH,
                        help="Which Jackett branch to cherry-pick from (default: master)")

    # GitHub / PR arguments
    parser.add_argument("--create-pr", action="store_true",
                        help="Whether to create a PR on GitHub after pushing.")
    parser.add_argument("--gh-token", default="",
                        help="GitHub personal access token for PR creation")
    parser.add_argument("--gh-repo-name", default="",
                        help="GitHub repo name in 'owner/repo' format for PR creation")
    parser.add_argument("--gh-base-branch", default="master",
                        help="Base branch for the PR (default: master)")
    parser.add_argument("--gh-pr-title", default="Indexer Sync PR",
                        help="Title for the PR")
    parser.add_argument("--gh-pr-body", default="Auto-created by Indexer Sync Script",
                        help="Body for the PR")

    return parser.parse_args()


def main():
    args = parse_arguments()

    # Global config overrides
    global MODE_CHOICE, PROWLARR_TARGET_BRANCH, PROWLARR_RELEASE_BRANCH
    global PUSH_MODE, PUSH_MODE_FORCE, SKIP_BACKPORT
    global JACKETT_BRANCH
    MODE_CHOICE = args.mode
    PROWLARR_TARGET_BRANCH = args.target_branch
    PROWLARR_RELEASE_BRANCH = args.release_branch
    PUSH_MODE = args.push
    PUSH_MODE_FORCE = args.force_push
    SKIP_BACKPORT = args.skip_backport
    JACKETT_BRANCH = args.jackett_branch

    # Determine dev mode
    global IS_DEV_EXEC, IS_JACKETT_DEV
    if MODE_CHOICE.lower() in ["normal", "n"]:
        IS_DEV_EXEC = False
        IS_JACKETT_DEV = False
    elif MODE_CHOICE.lower() in ["dev", "development", "d"]:
        IS_DEV_EXEC = True
        IS_JACKETT_DEV = False
        logger.warning("Development mode: skipping upstream resets, using local branches.")
    elif MODE_CHOICE.lower() in ["jackett", "j"]:
        IS_DEV_EXEC = True
        IS_JACKETT_DEV = True
        logger.warning("Jackett dev mode: skipping upstream resets, using local Jackett branch.")
    else:
        logger.error(f"Invalid mode: {MODE_CHOICE}")
        return 1

    # 1) Clone or open the local repo
    repo = clone_or_open_repo(PROWLARR_REPO_URL, args.local_repo)

    # 2) Ensure remote references exist
    ensure_remote(repo, PROWLARR_REMOTE_NAME, PROWLARR_REPO_URL)
    ensure_remote(repo, JACKETT_REMOTE_NAME, JACKETT_REPO_URL)

    # 3) If not jackett dev, fetch all
    if not IS_JACKETT_DEV:
        fetch_all_remotes(repo)

    # 4) Check out or create the target branch
    if not IS_DEV_EXEC and not IS_JACKETT_DEV:
        # Normal mode => we likely want to reset to remote/target
        remote_ref = f"{PROWLARR_REMOTE_NAME}/{PROWLARR_TARGET_BRANCH}"
        logger.info(f"Checking out branch {PROWLARR_TARGET_BRANCH} from {remote_ref}, forcing reset.")
        checkout_or_create_branch(repo, PROWLARR_TARGET_BRANCH, base_ref=remote_ref, force_reset=True)
    else:
        # Dev mode => do not reset from remote
        logger.info(f"Dev/Jackett mode => checking out or creating local {PROWLARR_TARGET_BRANCH} without resetting.")
        checkout_or_create_branch(repo, PROWLARR_TARGET_BRANCH, base_ref=None, force_reset=False)

    # 5) Identify the last pulled commit from Prowlarr logs
    #    We'll look in last ~20 commits for "jackett indexers as of <commit>"
    commits_log = repo.git.log("--format=%B", "-n", "20")
    lines = commits_log.splitlines()
    prowlarr_msgs = [ln for ln in lines if ln.startswith(PROWLARR_COMMIT_TEMPLATE)]
    if not prowlarr_msgs:
        logger.error("No prior 'jackett indexers as of' commit found in last 20 logs.")
        return 1
    recent_pulled_commit = None
    tokens = prowlarr_msgs[0].split()
    if len(tokens) >= 6:
        recent_pulled_commit = tokens[5]
    if not recent_pulled_commit:
        logger.error("Could not parse recent pulled commit from commit message!")
        return 2

    # 6) Identify Jackett's latest
    if IS_JACKETT_DEV:
        jackett_ref = f"{JACKETT_REMOTE_NAME}{JACKETT_BRANCH}"  # local dev style
    else:
        jackett_ref = f"{JACKETT_REMOTE_NAME}/{JACKETT_BRANCH}"

    try:
        jackett_latest = repo.git.rev_parse(jackett_ref)
    except git.GitCommandError as e:
        logger.error(f"Could not rev-parse {jackett_ref}: {e}")
        return 3

    if jackett_latest == recent_pulled_commit:
        logger.info("We are current with Jackett. Nothing to do.")
        return 0

    # 7) Gather commits to cherry-pick
    count_str = repo.git.rev_list("--count", f"{recent_pulled_commit}..{jackett_latest}")
    commit_count = int(count_str.strip())
    logger.info(f"There are {commit_count} commits to cherry-pick.")
    if commit_count > MAX_COMMITS_TO_PICK:
        logger.error(f"Commit count {commit_count} > {MAX_COMMITS_TO_PICK}; stopping.")
        return 4

    range_cmd = repo.git.log("--reverse", "--pretty=%H", f"{recent_pulled_commit}..{jackett_latest}")
    commits_to_pick = range_cmd.splitlines()

    # 8) Cherry-pick each
    # set some merge config
    repo.git.config("merge.directoryRenames", "true")
    repo.git.config("merge.verbosity", "0")

    for pick_commit in commits_to_pick:
        unmerged = list_unmerged_files(repo)
        if unmerged:
            logger.error(f"Conflicts exist before picking {pick_commit}: {unmerged}")
            input("Resolve conflicts, then press Enter to continue...")

        logger.info(f"Cherry-picking {pick_commit}")
        # e.g. git cherry-pick --no-commit --allow-empty ...
        try:
            repo.git.cherry_pick("--no-commit", "--allow-empty", "--keep-redundant-commits", pick_commit)
        except git.GitCommandError:
            # if conflicts => attempt resolution
            handle_conflict_resolution(repo)

        # revert config
        repo.git.config("merge.directoryRenames", "conflict")
        repo.git.config("merge.verbosity", "2")

    logger.info("Cherry-picking complete. Reviewing changes...")

    # revert changes to all schema.json
    repo.git.checkout("HEAD", "--", "definitions/v*/schema.json")

    # 9) Process new/modified indexers
    handle_new_indexers(repo)
    handle_modified_indexers(repo)

    if not SKIP_BACKPORT:
        handle_backporting_indexers(repo)
    else:
        logger.debug("Skipping backporting as requested.")

    # 10) Final commit
    cleanup_and_commit(repo)

    # 11) (Optional) Push
    if PUSH_MODE:
        push_branch(repo, PROWLARR_TARGET_BRANCH, force_with_lease=PUSH_MODE_FORCE)
    else:
        logger.info("Skipping push. Manually push or create PR later if desired.")

    # 12) (Optional) Create Pull Request
    if args.create_pr:
        if not args.gh_token or not args.gh_repo_name:
            logger.error("Cannot create PR: --gh-token and --gh-repo-name are required.")
        else:
            # The "head branch" for the PR might be just the local branch name if it’s the same repo.
            # If it's a fork, you'd do "YourUsername:branch". 
            # For simplicity, assume same repo => branch == PROWLARR_TARGET_BRANCH.
            head_branch_for_pr = PROWLARR_TARGET_BRANCH

            create_pull_request(
                token=args.gh_token,
                repo_name=args.gh_repo_name,
                base_branch=args.gh_base_branch,
                head_branch=head_branch_for_pr,
                title=args.gh_pr_title,
                body=args.gh_pr_body
            )

    logger.info("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
