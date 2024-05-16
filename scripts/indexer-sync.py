import os
import subprocess
import sys
import shutil
from datetime import datetime

# Constants and Environment Variable Overrides
PROWLARR_GIT_PATH = os.getenv("PROWLARR_GIT_PATH", "./")
PROWLARR_RELEASE_BRANCH = os.getenv("PROWLARR_RELEASE_BRANCH", "master")
PROWLARR_REMOTE_NAME = os.getenv("PROWLARR_REMOTE_NAME", "origin")
PROWLARR_REPO_URL = os.getenv("PROWLARR_REPO_URL", "https://github.com/Prowlarr/Indexers")
JACKETT_REPO_URL = os.getenv("JACKETT_REPO_URL", "https://github.com/Jackett/Jackett")
JACKETT_RELEASE_BRANCH = os.getenv("JACKETT_RELEASE_BRANCH", "master")
JACKETT_REMOTE_NAME = os.getenv("JACKETT_REMOTE_NAME", "z_Jackett")
JACKETT_PULLS_BRANCH = os.getenv("JACKETT_PULLS_BRANCH", "jackett-pulls")
PROWLARR_COMMIT_TEMPLATE = os.getenv("PROWLARR_COMMIT_TEMPLATE", "jackett indexers as of")
MIN_SCHEMA = int(os.getenv("MIN_SCHEMA", 9))
MAX_SCHEMA = int(os.getenv("MAX_SCHEMA", 9))
NEW_SCHEMA = MAX_SCHEMA + 1
RETRY_COUNT = int(os.getenv("RETRY_COUNT", 3))
COMMIT_THRESHOLD = int(os.getenv("COMMIT_THRESHOLD", 50))  # Threshold for excessive commits

# Utility Functions
def log_message(level, message):
    timestamp = datetime.now().strftime('%Y-%m-%d %H%M%S.%f')[:-3]
    print(f"{timestamp}|{level}|{message}")

def run_command(command, check=True):
    for attempt in range(RETRY_COUNT):
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
        elif attempt < RETRY_COUNT - 1:
            log_message("WARN", f"Error executing {command}: {result.stderr}. Retrying...")
        else:
            log_message("ERROR", f"Error executing {command}: {result.stderr}.")
            if check:
                sys.exit(result.returncode)
    return result.stdout.strip()

def check_required_commands():
    if not shutil.which("npx"):
        log_message("ERROR", "npx not found. Check your Node.js installation.")
        sys.exit(1)
    if "ajv-cli-servarr" not in run_command("npm list --depth=0") or "ajv-formats" not in run_command("npm list --depth=0"):
        log_message("ERROR", 'Required npm packages are missing. Run "npm install"')
        sys.exit(2)

def setup_logging(arg):
    global debug, trace, skipupstream
    debug, trace, skipupstream = False, False, False
    if arg == "debug":
        debug = True
        log_message("INFO", "Debug logging enabled")
    elif arg == "trace":
        debug, trace = True, True
        log_message("INFO", "Debug and trace logging enabled")
    elif arg == "dev":
        skipupstream = True
        log_message("INFO", "Skipping upstream; local only")

def configure_git():
    os.chdir(PROWLARR_GIT_PATH)
    run_command("git config advice.statusHints false")
    git_remotes = run_command("git remote -v")
    if PROWLARR_REMOTE_NAME not in git_remotes:
        run_command(f"git remote add {PROWLARR_REMOTE_NAME} {PROWLARR_REPO_URL}")
    if JACKETT_REMOTE_NAME not in git_remotes:
        run_command(f"git remote add {JACKETT_REMOTE_NAME} {JACKETT_REPO_URL}")
    log_message("INFO", "Configured Git")
    run_command("git fetch --all --prune --progress")

def handle_branches():
    local_exist = run_command(f"git branch --list {JACKETT_PULLS_BRANCH}")
    remote_pulls_check = run_command(f"git ls-remote --heads {PROWLARR_REMOTE_NAME} {JACKETT_PULLS_BRANCH}")
    if not remote_pulls_check:
        if local_exist:
            if not skipupstream:
                run_command(f"git reset --hard {PROWLARR_REMOTE_NAME}/{PROWLARR_RELEASE_BRANCH}")
            run_command(f"git checkout -B {JACKETT_PULLS_BRANCH}")
        else:
            run_command(f"git checkout -B {JACKETT_PULLS_BRANCH} {PROWLARR_REMOTE_NAME}/{PROWLARR_RELEASE_BRANCH} --no-track")
    else:
        if local_exist:
            if not skipupstream:
                run_command(f"git reset --hard {PROWLARR_REMOTE_NAME}/{JACKETT_PULLS_BRANCH}")
            run_command(f"git checkout -B {JACKETT_PULLS_BRANCH}")
        else:
            run_command(f"git checkout -B {JACKETT_PULLS_BRANCH} {PROWLARR_REMOTE_NAME}/{JACKETT_PULLS_BRANCH}")

def determine_schema_version(def_file):
    check_version = os.path.basename(os.path.dirname(def_file))
    schema = f"definitions/{check_version}/schema.json"
    result = run_command(f"npx ajv test -d {def_file} -s {schema} --valid -c ajv-formats --spec=draft2019", check=False)
    return check_version if "valid" in result else "v0"

def determine_best_schema_version(def_file):
    for i in range(MIN_SCHEMA, MAX_SCHEMA + 1):
        schema = f"definitions/v{i}/schema.json"
        result = run_command(f"npx ajv test -d {def_file} -s {schema} --valid -c ajv-formats --spec=draft2019", check=False)
        if "valid" in result:
            log_message("INFO", f"Definition {def_file} matches schema v{i}")
            return i
    log_message("ERROR", f"Definition {def_file} does not match max schema v{MAX_SCHEMA}. Review definition.")
    return 0

def review_and_cherry_pick():
    jackett_branch = f"{JACKETT_REMOTE_NAME}/{JACKETT_RELEASE_BRANCH}"
    existing_message = run_command("git log --format=%B -n1")
    prowlarr_commits = run_command(f"git log --format=%B -n1 -n 20 | grep \"^{PROWLARR_COMMIT_TEMPLATE}\"")
    recent_pulled_commit = prowlarr_commits.split()[4]
    jackett_recent_commit = run_command(f"git rev-parse {jackett_branch}")
    commit_range = run_command(f"git log --reverse --pretty=\"%n%H\" {recent_pulled_commit}..{jackett_recent_commit}")
    commit_count = run_command(f"git rev-list --count {recent_pulled_commit}..{jackett_recent_commit}")

    if jackett_recent_commit == recent_pulled_commit:
        log_message("INFO", "We are current with Jackett; nothing to do")
        sys.exit(0)
    if not recent_pulled_commit:
        log_message("ERROR", "Recent pulled commit is empty. Failing.")
        sys.exit(3)

    log_message("INFO", f"Commit Range: {commit_range}")
    log_message("INFO", f"{commit_count} commits to cherry-pick")
    
    if commit_count > COMMIT_THRESHOLD:
        input(f"Commit range exceeds {COMMIT_THRESHOLD} commits. Press any key to continue...")

    run_command("git config merge.directoryRenames true")
    run_command("git config merge.verbosity 0")
    
    for pick_commit in commit_range.split():
        has_conflicts = run_command("git ls-files --unmerged")
        if has_conflicts:
            log_message("ERROR", f"Conflicts exist [{has_conflicts}] - Cannot cherry-pick")
            input("Pausing due to conflicts. Press any key to continue when resolved.")
            log_message("INFO", "Continuing cherry-picking")
        
        log_message("INFO", f"Cherry-picking {pick_commit}")
        run_command(f"git cherry-pick --no-commit --rerere-autoupdate --allow-empty --keep-redundant-commits {pick_commit}")

        if trace:
            input("Reached - Conflict checking; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort.")
        
        handle_conflicts()

def handle_conflicts():
    has_conflicts = run_command("git ls-files --unmerged")
    if has_conflicts:
        readme_conflicts = [file for file in has_conflicts.split() if "README.md" in file]
        schema_conflicts = [file for file in has_conflicts.split() if ".schema.json" in file]
        nonyml_conflicts = [file for file in has_conflicts.split() if file.endswith((".cs", ".js", ".iss", ".html"))]
        yml_conflicts = [file for file in has_conflicts.split() if file.endswith(".yml")]

        if readme_conflicts:
            log_message("INFO", "README conflict exists; using Prowlarr README")
            if trace:
                input("Reached - README Conflict; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort.")
            run_command("git checkout --ours README.md")
            run_command("git add --f README.md")
              if schema_conflicts:
        log_message("INFO", f"Schema conflict exists; using Jackett Schema and creating version {NEW_SCHEMA}")
        if trace:
            input("Reached - Schema Conflict; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort.")
        for conflict in schema_conflicts:
            run_command(f"mv {conflict} {PROWLARR_GIT_PATH}/{NEW_SCHEMA}/schema.json")
            run_command(f"git checkout --theirs *schema.json")
            run_command(f"git add --f *schema.json")

    if nonyml_conflicts:
        log_message("INFO", "Non-YML conflicts exist; removing .cs, .js, .iss, .html")
        if trace:
            input("Reached - Non-YML Conflict; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort.")
        run_command("git checkout --ours package.json")
        run_command("git checkout --ours package-lock.json")
        run_command("git checkout --ours .editorconfig")
        for conflict in nonyml_conflicts:
            run_command(f"git rm --f --q --ignore-unmatch {conflict}")

    if yml_conflicts:
        handle_yml_conflicts(yml_conflicts)
              if schema_conflicts:
            log_message("INFO", f"Schema conflict exists; using Jackett Schema and creating version {NEW_SCHEMA}")
            if trace:
                input("Reached - Schema Conflict; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort.")
            for conflict in schema_conflicts:
                run_command(f"mv {conflict} {PROWLARR_GIT_PATH}/{NEW_SCHEMA}/schema.json")
                run_command(f"git checkout --theirs *schema.json")
                run_command(f"git add --f *schema.json")

        if nonyml_conflicts:
            log_message("INFO", "Non-YML conflicts exist; removing .cs, .js, .iss, .html")
            if trace:
                input("Reached - Non-YML Conflict; Pausing for debugging - Press any key to continue or [Ctrl-C] to abort.")
            run_command("git checkout --ours package.json")
            run_command("git checkout --ours package-lock.json")
            run_command("git checkout --ours .editorconfig")
            for conflict in nonyml_conflicts:
                run_command(f"git rm --f --q --ignore-unmatch {conflict}")

        if yml_conflicts:
            handle_yml_conflicts(yml_conflicts)

def handle_yml_conflicts(yml_conflicts):
    log_message("INFO", f"YML conflict exists; {yml_conflicts}")
    yml_remove = run_command("git status --porcelain | grep yml | grep -v 'definitions/' | awk -F '[ADUMRC]{1,2} ' '{print $2}' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ''); print }'")
    for file in yml_remove.split():
        log_message("INFO", f"Removing non-definition yml; {file}")
        run_command(f"git rm --f --ignore-unmatch {file}")

if __name__ == "__main__":
    check_required_commands()
    setup_logging(sys.argv[1] if len(sys.argv) > 1 else "")
    configure_git()
    handle_branches()
    review_and_cherry_pick()
