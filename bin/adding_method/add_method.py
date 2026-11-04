#!/usr/bin/env python3
"""Add a new method to the MESSI pipeline, and test it.

  add_method.py                     ask a few questions, then generate the method
  add_method.py --method NAME --language R --container rgcca --yes
  add_method.py check NAME          run the three functions on synthetic data
  add_method.py check-image NAME    does the method's container qualify?
  add_method.py test NAME           run it through Nextflow on rosmap

Standard library only. Full guide: docs/adding_a_method.md
"""

import argparse
import difflib
import glob
import io
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
TEMPLATES = HERE / "templates"
DOC = "docs/adding_a_method.md"
ME = "bin/adding_method/add_method.py"

NEXTFLOW_IMAGE = "nextflow/nextflow:24.10.2"
TEST_ROOT = "/tmp/messi_add_method"

LANGUAGES = {
    "R": {
        "ext": "R",
        "data_ext": "rds",
        "folder": "r",
        "data_kind": "MultiAssayExperiment",
        "cv_file": "subworkflows/cross_validation/r/main.nf",
        "channel": "mae_copy",
        "fs_channel": "mae_data",
        "list_slot": "r_methods",
        "reuse": ["rgcca", "caret_multimodal", "mofa"],
        "base_image": "tonyliang19/r_method_base_dev",
    },
    "Python": {
        "ext": "py",
        "data_ext": "pkl",
        "folder": "python",
        "data_kind": "MuData",
        "cv_file": "subworkflows/cross_validation/python/main.nf",
        "channel": "mu_copy",
        "fs_channel": "mu_data",
        "list_slot": "python_methods",
        "reuse": ["sklearn", "integrao", "mogonet", "sksurv"],
        "base_image": "tonyliang19/python_method_base_dev",
    },
}
EXAMPLES = ("logistic",)
DEFAULT_USER = "tonyliang19"


class UserError(Exception):
    """A mistake the user can fix: print the message, no traceback."""


def read(path):
    with open(str(path), encoding="utf-8", newline="") as handle:
        return handle.read()


def write(path, text):
    """Always LF: a CRLF shebang breaks the script on Linux."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(str(path), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def rel(path):
    return Path(path).relative_to(REPO).as_posix()


# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------


def existing_names():
    names = set()
    for folder in (REPO / "modules", REPO / "subworkflows" / "methods"):
        names.update(p.name for p in folder.iterdir() if p.is_dir())
    names.update(re.findall(r"^\s*skip_(\w+)\s*=", read(REPO / "nextflow.config"), re.M))
    return names


def name_problem(name):
    """Return why this method name cannot be used, or None."""
    if not re.match(r"^[a-z][a-z0-9_]*$", name) or name.endswith("_") or "__" in name:
        return ("Use lowercase letters, digits and single underscores, starting with a letter "
                "(for example: my_method).")
    if len(name) > 40:
        return "Use at most 40 characters."
    if "sim" in name:
        # merge_selected_features.R treats any file name containing "sim" as a
        # simulated dataset, and then fails on real data.
        return ("The name cannot contain 'sim': merge_selected_features.R treats file names "
                "containing it as simulated data.")
    if name in existing_names():
        return "A method or module called '{}' already exists. Choose another name.".format(name)
    return None


def language_of(text):
    value = text.strip().lower()
    if value in ("r",):
        return "R"
    if value in ("python", "py"):
        return "Python"
    return None


def declared_images():
    """label -> image, from the withLabel lines of nextflow.config."""
    pattern = r"withLabel:\s*(\w+)\s*\{\s*container\s*=\s*['\"]([^'\"]+)['\"]"
    return dict(re.findall(pattern, read(REPO / "nextflow.config")))


def resolve_container(text, method, language):
    """Return (image, is_new), or raise UserError."""
    value = text.strip()
    if value == "new":
        return "{}/{}:latest".format(DEFAULT_USER, method), True
    if value.startswith("new:"):
        return value[4:], True
    images = declared_images()
    if value in images:
        return images[value], False
    for image in images.values():
        if value == image.split("/")[-1].split(":")[0]:
            return image, False
    if "/" in value or ":" in value:
        return value, False
    raise UserError("Unknown container '{}'. Use one of: {}, new, or a full image name such as "
                    "tonyliang19/rgcca:latest.".format(value, ", ".join(LANGUAGES[language]["reuse"])))


# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------


def ask(question, default=None):
    suffix = " [{}]".format(default) if default else ""
    try:
        answer = input("{}{}: ".format(question, suffix)).strip()
    except EOFError:
        raise UserError("Input ended before all questions were answered. Nothing was written.\n"
                        "To run without questions use: --method NAME --language R --container rgcca --yes")
    return answer or default or ""


def prompt_name(default):
    print("\nStep 1 of 3: method name")
    print("  Used for the module folder, the process names and the skip_<name> parameter.")
    print("  Lowercase letters, digits and underscores.")
    while True:
        name = ask("Method name", default)
        problem = name_problem(name)
        if not problem:
            return name
        print("  Not usable: " + problem)


def prompt_language():
    print("\nStep 2 of 3: language")
    print("  The language you will write the three functions in.")
    while True:
        language = language_of(ask("Language (R or Python)", "R"))
        if language:
            return language
        print("  Not usable: please answer R or Python.")


def prompt_container(method, language):
    print("\nStep 3 of 3: container")
    print("  Every step of your method runs inside one container image, so the image must")
    print("  have the packages your code uses. Nothing to install? Reuse an existing image.")
    images = declared_images()
    reuse = [label for label in LANGUAGES[language]["reuse"] if label in images]
    for number, label in enumerate(reuse, 1):
        print("  {}) reuse {}".format(number, images[label]))
    print("  {}) new: generate a Dockerfile FROM {} that you build and push".format(
        len(reuse) + 1, LANGUAGES[language]["base_image"]))
    while True:
        answer = ask("Choice (number, or a full image name)", "1")
        if answer.isdigit():
            number = int(answer)
            if 1 <= number <= len(reuse):
                return reuse[number - 1]
            if number == len(reuse) + 1:
                return "new"
            print("  Not usable: choose a number from 1 to {}.".format(len(reuse) + 1))
            continue
        try:
            resolve_container(answer, method, language)
            return answer
        except UserError as error:
            print("  Not usable: {}".format(error))


def confirm():
    while True:
        answer = ask("Write these files? (y/n)", "y").lower()
        if answer in ("y", "yes"):
            return True
        if answer in ("n", "no"):
            return False
        print("  Please answer y or n.")


# ---------------------------------------------------------------------------
# Generating: everything is computed in memory first, then written
# ---------------------------------------------------------------------------


def render(template, values):
    text = read(TEMPLATES / template)
    for key, value in values.items():
        text = text.replace("{{ " + key + " }}", value)
    left = re.search(r"\{\{ *\w+ *\}\}", text)
    if left:
        raise RuntimeError("Unfilled {} in template {}".format(left.group(0), template))
    return text


def new_files(method, language, example, is_new_image):
    info = LANGUAGES[language]
    ext, folder = info["ext"], info["folder"]
    bin_dir = "modules/{}/resources/usr/bin".format(method)
    core_path = "{}/{}_core.{}".format(bin_dir, method, ext)
    values = {
        "method": method,
        "METHOD": method.upper(),
        "ext": ext,
        "data_ext": info["data_ext"],
        "data_kind": info["data_kind"],
        "core_path": core_path,
    }
    core_template = "{}/core_{}.{}".format(folder, example or "blank", ext)
    files = {
        "modules/{}/main.nf".format(method): render("module_main.nf", values),
        "subworkflows/methods/{}/main.nf".format(method): render("subworkflow_main.nf", values),
        core_path: render(core_template, values),
        "{}/messi_run.{}".format(bin_dir, ext): read(TEMPLATES / folder / "messi_run.{}".format(ext)),
        "{}/messi_contract.{}".format(bin_dir, ext): read(TEMPLATES / folder / "messi_contract.{}".format(ext)),
    }
    if is_new_image:
        files["containers/dockerfiles/{}.Dockerfile".format(method)] = render(folder + "/Dockerfile", values)
    return files


def wiring(method, language, image):
    """(file, marker slot, lines to insert above the marker)."""
    info = LANGUAGES[language]
    upper = method.upper()
    cv = info["cv_file"]
    fs = "subworkflows/feature_selection/main.nf"
    return [
        (cv, "include", ['include {{ {} }} from "${{subworkflowDir}}/methods/{}"'.format(upper, method)]),
        (cv, "skip", ["skip_{0} = params.skip_{0} || outcome_type != 'classification'".format(method)]),
        (cv, "run", [
            "// {}".format(upper),
            "{}_results = Channel.empty()".format(method),
            "if (!skip_{}) {{".format(method),
            "  {} ( {} )".format(upper, info["channel"]),
            "  {}_results = {}.out.csv_results".format(method, upper),
            "}",
        ]),
        (cv, "mix", [".mix( {}_results )".format(method)]),
        ("subworkflows/cross_validation/main.nf", info["list_slot"], ["'{}',".format(method)]),
        (fs, "include", ['include {{ {0}_SELECT_FEATURE }} from "${{modulesDir}}/{1}"'.format(upper, method)]),
        (fs, "skip", ["skip_{0} = params.skip_{0} || params.outcome_type != 'classification'".format(method)]),
        (fs, "run", [
            "{}_features = Channel.empty()".format(method),
            "{}_hyperparams = Channel.empty()".format(method),
            "if (!skip_{}) {{".format(method),
            "  {}_SELECT_FEATURE ( {} )".format(upper, info["fs_channel"]),
            "  {0}_features = {1}_SELECT_FEATURE.out.features".format(method, upper),
            "  {0}_hyperparams = {1}_SELECT_FEATURE.out.hyperparameters".format(method, upper),
            "}",
        ]),
        (fs, "features_mix", [".mix( {}_features )".format(method)]),
        (fs, "hyperparams_mix", [".mix( {}_hyperparams )".format(method)]),
        ("nextflow.config", "skip_params", ["skip_{} = false".format(method)]),
        ("nextflow.config", "containers", ["withLabel: {} {{ container = '{}' }}".format(method, image)]),
    ]


def apply_wiring(texts, target, slot, lines):
    """Insert lines above the marker line, with its indent. Already present: no change."""
    text = texts[target]
    if lines[0] in (line.strip() for line in text.splitlines()):
        return
    marker = "add_method:" + slot
    match = re.search(r"^([ \t]*)//\s*" + re.escape(marker) + r"\b.*$", text, re.M)
    if not match:
        raise UserError("Cannot find the marker comment '// {}' in {}. Restore it from git "
                        "and try again. Nothing was written.".format(marker, target))
    block = "".join(match.group(1) + line + "\n" for line in lines)
    texts[target] = text[:match.start()] + block + text[match.start():]


def plan(method, language, example, image, is_new_image):
    files = new_files(method, language, example, is_new_image)
    clashes = [path for path in files if (REPO / path).exists()]
    clashes += [path for path in ("modules/" + method, "subworkflows/methods/" + method)
                if (REPO / path).exists()]
    if clashes:
        raise UserError("Refusing to overwrite an existing method. Already there: {}".format(", ".join(sorted(set(clashes)))))
    edits = wiring(method, language, image)
    texts = {target: read(REPO / target) for target, _, _ in edits}
    originals = dict(texts)
    for target, slot, lines in edits:
        apply_wiring(texts, target, slot, lines)
    changed = {target: text for target, text in texts.items() if text != originals[target]}
    return files, changed, originals


def inserted_lines(original, updated):
    """The lines add_method adds to a file, in order. Insertions only, no context."""
    added = []
    for line in difflib.unified_diff(original.splitlines(), updated.splitlines(), n=0):
        if line.startswith("+") and not line.startswith("+++"):
            added.append(line[1:])
    return added


def execute(files, changed):
    written = []
    backups = {}
    try:
        for path, text in sorted(files.items()):
            target = REPO / path
            write(target, text)
            written.append(target)
            if "/messi_run." in path:
                target.chmod(0o755)
        for path, text in sorted(changed.items()):
            backups[path] = read(REPO / path)
            write(REPO / path, text)
    except OSError as error:
        for target in written:
            if target.exists():
                target.unlink()
        for path, text in backups.items():
            write(REPO / path, text)
        raise UserError("Could not write files ({}). The changes were undone.".format(error))


def skip_flags(*methods):
    """--skip_x true for every other method: the way to run only these ones."""
    names = re.findall(r"^\s*skip_(\w+)\s*=", read(REPO / "nextflow.config"), re.M)
    return " ".join("--skip_{} true".format(name) for name in names if name not in methods)


def sockeye_steps(method):
    return ("module load CVMFS_CC apptainer/1.3.5 java/21.0.1 nextflow/24.10.2\n"
            "     set -a; source .env; set +a\n"
            "     nextflow run main.nf -profile sockeye,test --samplesheet data/samplesheet_test_small.csv \\\n"
            "       --selectFeature true --outdir results/test_{0} -ansi-log false \\\n"
            "       $(python3 {1} test {0} --print-skip-flags)".format(method, ME))


def print_next_steps(method, language, example, image, is_new_image):
    info = LANGUAGES[language]
    core = "modules/{0}/resources/usr/bin/{0}_core.{1}".format(method, info["ext"])
    n = 1
    print("\nDone. Next steps:\n")
    if example:
        print("  {}. This method is already filled in as a worked example ({}). To read it, open:".format(n, example))
    else:
        print("  {}. Open this one file (the only file you edit):".format(n))
    print("       " + core)
    n += 1
    if example:
        print("  {}. See the three functions it defines: fit, predict_proba, feature_weights.".format(n))
    else:
        print("  {}. Fill in the three functions: fit, predict_proba, feature_weights.".format(n))
        print("     Each one shows its input and output shapes and a minimal example in comments.")
    n += 1
    print("  {}. Self-check on synthetic data, no Nextflow or containers:".format(n))
    print("       python {} check {}".format(ME, method))
    n += 1
    if is_new_image:
        print("  {}. Add your packages to containers/dockerfiles/{}.Dockerfile, then build and push:".format(n, method))
        print("       docker build -t {0} -f containers/dockerfiles/{1}.Dockerfile containers/dockerfiles".format(image, method))
        print("       docker push {}".format(image))
        n += 1
    print("  {}. Check that the container qualifies:".format(n))
    print("       python {} check-image {}".format(ME, method))
    n += 1
    print("  {}. Run only this method through Nextflow, on the small rosmap dataset:".format(n))
    print("       python {} test {}".format(ME, method))
    n += 1
    print("  {}. On Sockeye, run only this method on data/samplesheet_test_small.csv:".format(n))
    if is_new_image:
        print("     On the login node, which has internet, first pull the new image:")
        print('       apptainer pull --dir "$APPTAINER_IMAGE_CACHE_DIR" {0}.img docker://{1}'.format(
            image.replace("/", "-").replace(":", "-"), image))
    print("     " + sockeye_steps(method))
    print("\n  Guide: {}".format(DOC))
    print("  To skip this method in a run: --skip_{} true".format(method))
    if os.name == "nt":
        print("\n  Windows note: Git needs to be told the script is executable before you commit:")
        print("       git add --chmod=+x modules/{0}/resources/usr/bin/messi_run.{1}".format(method, info["ext"]))


def cmd_generate(args):
    interactive = not args.yes
    if args.language:
        language = language_of(args.language)
        if not language:
            raise UserError("Unknown language '{}'. Use R or Python.".format(args.language))
    else:
        language = None

    if args.method:
        problem = name_problem(args.method)
        if problem:
            raise UserError("Cannot use method name '{}'. {}".format(args.method, problem))
        method = args.method
    elif interactive:
        print("Add a method to MESSI. Press Enter to accept the value in [brackets].")
        method = prompt_name("logistic_r" if args.example else "my_method")
    else:
        raise UserError("--method is required with --yes.")

    if language is None:
        if not interactive:
            raise UserError("--language is required with --yes.")
        language = prompt_language()

    if args.container:
        container = args.container
    elif interactive:
        container = prompt_container(method, language)
    else:
        container = LANGUAGES[language]["reuse"][0]
    image, is_new_image = resolve_container(container, method, language)

    files, changed, originals = plan(method, language, args.example, image, is_new_image)

    print("\nMethod '{}' in {}, container {}{}".format(
        method, language, image, " (new Dockerfile)" if is_new_image else ""))
    print("\nFiles to create:")
    for path in sorted(files):
        print("  " + path)
    total = sum(len(inserted_lines(originals[path], changed[path])) for path in changed)
    print("\nFiles to modify ({} lines inserted, each above its '// add_method:<slot>' marker):".format(total))
    for path in sorted(changed):
        added = inserted_lines(originals[path], changed[path])
        print("  {}  (+{})".format(path, len(added)))
        for line in added:
            print("      + " + line.strip())
    print()

    if args.dry_run:
        print("Dry run: nothing was written.")
        return 0
    if not args.yes and not confirm():
        print("Nothing was written.")
        return 0
    execute(files, changed)
    print_next_steps(method, language, args.example, image, is_new_image)
    return 0


# ---------------------------------------------------------------------------
# Finding a generated method
# ---------------------------------------------------------------------------


def locate(method):
    """Return (language, folder with the core file)."""
    bin_dir = REPO / "modules" / method / "resources" / "usr" / "bin"
    for language, info in LANGUAGES.items():
        if (bin_dir / "{}_core.{}".format(method, info["ext"])).exists():
            return language, bin_dir
    raise UserError("No generated method called '{}': cannot find modules/{}/resources/usr/bin/{}_core.R or .py."
                    .format(method, method, method))


def find_rscript():
    env = os.environ.get("RSCRIPT")
    if env:
        return env
    found = shutil.which("Rscript")
    if found:
        return found
    if os.name == "nt":
        pattern = os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "R", "R-*", "bin", "x64", "Rscript.exe")
        matches = sorted(glob.glob(pattern))
        if matches:
            return matches[-1]
    raise UserError("Cannot find Rscript. Install R, or set the RSCRIPT environment variable to its path.\n"
                    "Or run the check inside the container instead: python {} check-image <method>".format(ME))


def cmd_check(args):
    language, bin_dir = locate(args.method)
    if language == "R":
        command = [find_rscript(), "--vanilla", str(bin_dir / "messi_run.R"), "check", "--method=" + args.method]
    else:
        command = [sys.executable, "-B", str(bin_dir / "messi_run.py"), "check", "--method=" + args.method]
    return subprocess.call(command)


# ---------------------------------------------------------------------------
# Docker helpers
# ---------------------------------------------------------------------------


def docker_env():
    env = dict(os.environ)
    env["MSYS_NO_PATHCONV"] = "1"  # Git Bash must not rewrite /tmp/... in arguments
    return env


def docker(*arguments, **kwargs):
    return subprocess.run(["docker"] + list(arguments), env=docker_env(), **kwargs)


def docker_output(*arguments, stdin=None):
    done = docker(*arguments, input=stdin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return done.returncode, done.stdout.decode("utf-8", "replace").replace("\r\n", "\n")


def require_docker():
    if not shutil.which("docker"):
        raise UserError("Cannot find docker. Install Docker and start it.")
    code, output = docker_output("info", "--format", "{{.ServerVersion}}")
    if code != 0:
        raise UserError("The Docker daemon is not reachable. Start Docker and try again.\n" + output.strip())


def method_image(method):
    image = declared_images().get(method)
    if not image:
        raise UserError("nextflow.config has no 'withLabel: {} {{ container = ... }}' line.".format(method))
    return image


def image_available(image):
    return docker_output("image", "inspect", image)[0] == 0


# ---------------------------------------------------------------------------
# check-image: does this image qualify?
# ---------------------------------------------------------------------------


def run_user():
    """Run as the pipeline does: a non-root user with no passwd entry for it."""
    if hasattr(os, "getuid") and os.getuid() != 0:
        return "{}:{}".format(os.getuid(), os.getgid())
    return "1000:1000"


def in_image(image, shell_command, stdin=None):
    arguments = ["run", "--rm", "-u", run_user(), "--entrypoint", "", "-e", "MESSI_CHECK_IMAGE=1"]
    if stdin is not None:
        arguments.append("-i")
    arguments += [image, "sh", "-c", shell_command]
    return docker_output(*arguments, stdin=stdin)


def tar_folder(folder):
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as tar:
        for path in sorted(folder.iterdir()):
            if path.is_file():
                info = tar.gettarinfo(str(path), arcname=path.name)
                info.mode = 0o755
                info.uid = info.gid = 0
                with open(str(path), "rb") as handle:
                    tar.addfile(info, handle)
    return buffer.getvalue()


def install_line(language, package, bioconductor=False):
    if language == "Python":
        return 'RUN pip install {}==<version>'.format(package)
    if bioconductor:
        return "RUN Rscript -e \"BiocManager::install('{}')\"".format(package)
    return "RUN Rscript -e \"install.packages('{}')\"".format(package)


def cmd_check_image(args):
    require_docker()
    language, bin_dir = locate(args.method)
    image = args.image or method_image(args.method)
    manifest = json.loads(read(HERE / "required_packages.json"))
    dockerfile = "containers/dockerfiles/{}.Dockerfile".format(args.method)
    failed = [False]

    def result(status, item, detail="", fix=None):
        print("  {:<4} {:<24} {}".format(status, item, detail))
        if fix:
            print("       {:<24} Fix: {}".format("", fix))
        if status == "FAIL":
            failed[0] = True

    print("Checking image {} for method '{}' ({}), run as -u {} --entrypoint ''\n".format(
        image, args.method, language, run_user()))

    if not image_available(image):
        code, output = docker_output("pull", image)
        if code != 0:
            hint = "docker build -t {} -f {} containers/dockerfiles".format(image, dockerfile)
            result("FAIL", "1. image starts", "cannot find or pull this image", hint)
            print("\nResult: FAIL")
            return 1

    # 1. Starts, and has what Nextflow's task wrapper uses
    commands = " ".join(manifest["commands"])
    probe = 'for c in {}; do command -v "$c" >/dev/null 2>&1 && echo "HAS $c" || echo "NO $c"; done'.format(commands)
    code, output = in_image(image, probe)
    if code != 0:
        result("FAIL", "1. image starts", output.strip()[-300:], "The image must run with sh as a non-root user.")
        print("\nResult: FAIL")
        return 1
    result("PASS", "1. image starts", "as a non-root user with no entrypoint")
    for command in manifest["commands"]:
        if "HAS {}".format(command) in output:
            result("PASS", "1. command " + command, "found")
        else:
            result("FAIL", "1. command " + command, "not found",
                   "Nextflow's task wrapper needs it. Add it to the image with the system package manager.")

    # 2. Runtime and the packages the fixed wrappers load
    packages = manifest[language]
    if language == "R":
        probe = ("Rscript -e 'for (p in c({})) cat(\"PKG\", p, requireNamespace(p, quietly = TRUE), \"\\n\"); "
                 "cat(\"VERSION\", R.version.string, \"\\n\"); cat(\"LIBS\", .libPaths(), \"\\n\")'").format(
                     ",".join('"{}"'.format(p) for p in packages))
    else:
        probe = ("python -c 'import importlib.util as u, sys; "
                 "[print(\"PKG\", p, u.find_spec(p) is not None) for p in {}]; "
                 "print(\"VERSION\", \"Python\", sys.version.split()[0]); "
                 "print(\"LIBS\", *sys.path)'").format(json.dumps(packages))
    code, output = in_image(image, probe)
    runtime = "Rscript" if language == "R" else "python"
    if "VERSION" not in output:
        base = LANGUAGES[language]["base_image"]
        result("FAIL", "2. runtime " + runtime, output.strip()[-300:], "Use an image built FROM {}.".format(base))
        print("\nResult: FAIL")
        return 1
    version = re.search(r"^VERSION (.+)$", output, re.M).group(1).strip()
    result("PASS", "2. runtime " + runtime, version)
    for package in packages:
        if re.search(r"^PKG {} (TRUE|True)\b".format(re.escape(package)), output, re.M):
            result("PASS", "2. package " + package, "loads")
        else:
            result("FAIL", "2. package " + package, "missing, the MESSI wrappers need it",
                   "Add to {}: {}".format(dockerfile, install_line(language, package, bioconductor=language == "R")))
    libs = re.search(r"^LIBS (.+)$", output, re.M)
    home_paths = [p for p in (libs.group(1).split() if libs else []) if re.match(r"^(/home/|/root/)", p)]

    # 3. The developer's functions, inside the image, through the same validators
    script = "messi_run.{}".format(LANGUAGES[language]["ext"])
    launch = "Rscript --vanilla" if language == "R" else "python -B"
    shell = ('d=$(mktemp -d) && tar xf - -C "$d" && '
             '{} "$d/{}" check --method={}').format(launch, script, args.method)
    code, output = in_image(image, shell, stdin=tar_folder(bin_dir))
    print("\n  3. Your functions inside the image:")
    shown = [line for line in output.splitlines() if not line.startswith("HOME-PACKAGES")]
    print("\n".join("     " + line for line in shown))
    if code == 0:
        result("PASS", "3. your three functions", "ran on synthetic data, through the same validators as check")
    else:
        missing = re.findall(r"no package called .([A-Za-z0-9._]+).", output)
        missing += re.findall(r"No module named '([A-Za-z0-9._]+)'", output)
        if missing:
            for package in sorted(set(missing)):
                result("FAIL", "3. your three functions", "the image lacks the package '{}'".format(package),
                       "Add to {}: {}\n       {:<24} Then rebuild, or choose an image that has it.".format(
                           dockerfile, install_line(language, package.split(".")[0]), ""))
        else:
            result("FAIL", "3. your three functions", "see the messages above",
                   "Fix the functions in modules/{0}/resources/usr/bin/{0}_core.{1}".format(
                       args.method, LANGUAGES[language]["ext"]))

    # 4. Packages under a home directory can vanish under Docker and Apptainer mounts
    loaded = re.search(r"^HOME-PACKAGES: ?(.+)$", output, re.M)
    if loaded:
        result("WARN", "4. packages under home", loaded.group(1).strip(),
               "Install into the system library: Docker mounts into /home/rstudio/... and Apptainer binds $HOME over it.")
    elif home_paths:
        result("WARN", "4. library paths in home", " ".join(home_paths),
               "Do not install packages here: Docker mounts into /home/rstudio/... and Apptainer binds $HOME over it.")
    else:
        result("PASS", "4. packages under home", "none used")

    # 5. Architecture
    code, output = docker_output("image", "inspect", "--format", "{{.Architecture}}", image)
    architecture = output.strip()
    if architecture == "amd64":
        result("PASS", "5. architecture", architecture)
    else:
        result("WARN", "5. architecture", architecture,
               "Linux clusters such as Sockeye need amd64: docker build --platform linux/amd64 ...")

    print("\nResult: {}".format("FAIL" if failed[0] else "PASS"))
    if not failed[0]:
        print("Note: this passing on Docker does not prove Apptainer behaviour. See 'Is my container good enough?' in " + DOC)
    return 1 if failed[0] else 0


# ---------------------------------------------------------------------------
# test: the real thing, Nextflow on rosmap
# ---------------------------------------------------------------------------

TEST_PATHS = ["main.nf", "nextflow.config", "conf", "modules", "subworkflows", "workflows", "bin"]


def tar_repo(extra):
    """The pipeline as a tar with Linux modes, whatever the host filesystem says."""
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as tar:

        def add(path, arcname):
            info = tar.gettarinfo(str(path), arcname=arcname)
            info.uid = info.gid = 0
            with open(str(path), "rb") as handle:
                info.mode = 0o755 if handle.read(2) == b"#!" else 0o644
            with open(str(path), "rb") as handle:
                tar.addfile(info, handle)

        for name in TEST_PATHS:
            source = REPO / name
            paths = [source] if source.is_file() else sorted(p for p in source.rglob("*") if p.is_file())
            for path in paths:
                if "__pycache__" not in path.parts:
                    add(path, path.relative_to(REPO).as_posix())
        for arcname, data in extra.items():
            info = tarfile.TarInfo(arcname)
            info.size = len(data)
            info.mode = 0o644
            tar.addfile(info, io.BytesIO(data))
        # Inside work/ so that task containers can see it: Nextflow mounts work/ into each one.
        add(REPO / "data" / "rosmap.tar.gz", "work/_inputs/rosmap.tar.gz")
    return buffer.getvalue()


def summarise(methods, out_dir, fetch):
    """Copy the key published files to a flat folder and say what is there.

    fetch(name, target) copies one published file, and returns an error message or None.
    Flat because the published paths are deep and Windows limits a path to 260 characters.
    """
    names = ["{}-result.csv".format(method) for method in methods]
    names += ["all_feature_selection_results.csv", "selected_hyperparameters.csv", "metrics.csv"]
    ok = True
    print("\nPublished files, copied to {}:".format(rel(out_dir)))
    for name in names:
        target = out_dir / name
        problem = fetch(name, target)
        if problem:
            print("  FAIL {}: {}".format(name, problem))
            ok = False
            continue
        rows = len(read(target).strip().splitlines()) - 1
        print("  {} {}: {} rows".format("PASS" if rows > 0 else "FAIL", name, rows))
        ok = ok and rows > 0
    metrics = out_dir / "metrics.csv"
    if metrics.exists():
        print("\nMetrics:")
        print("\n".join("  " + line for line in read(metrics).strip().splitlines()))
    return ok


def native_nextflow():
    """The nextflow on PATH. Nextflow does not run natively on Windows."""
    return None if os.name == "nt" else shutil.which("nextflow")


def methods_of(args):
    return [args.method] + (args.also or [])


def nextflow_command(script, profile, outdir, samplesheet, args):
    command = ["nextflow", "run", script, "-profile", profile + ",test", "-ansi-log", "false",
               "--outdir", outdir, "--samplesheet", samplesheet,
               "--selectFeature", "true", "--k_fold_number", str(args.folds)]
    command += skip_flags(*methods_of(args)).split()
    if args.stub:
        command.append("-stub")
    return command


def require_built_image(method):
    image = method_image(method)
    dockerfile = REPO / "containers" / "dockerfiles" / "{}.Dockerfile".format(method)
    if dockerfile.exists() and not image_available(image):
        raise UserError("The image {0} is not built yet. Build it first:\n"
                        "  docker build -t {0} -f {1} containers/dockerfiles".format(image, rel(dockerfile)))


def test_native(args, nextflow):
    """Linux or Mac with Nextflow installed: run the repository in place."""
    method = args.method
    out_dir = REPO / "results" / "add_method_test" / method
    outdir = out_dir / "nextflow_output"
    work_dir = REPO / "work"
    # tar_path is a plain string that Nextflow does not stage, so the file must be somewhere
    # task containers can see: Docker gets work/ mounted, and Apptainer gets the --bind below.
    input_tar = work_dir / "_inputs" / "rosmap.tar.gz"
    samplesheet = out_dir / "samplesheet_local.csv"
    stub_script = REPO / "_stub_test_{}.nf".format(method)
    script = stub_script.name if args.stub else "main.nf"

    command = nextflow_command(script, args.profile, outdir.as_posix(), samplesheet.as_posix(), args)
    command += ["-work-dir", work_dir.as_posix()]
    bind_config = out_dir / "apptainer_bind.config"
    if args.profile == "apptainer":
        command += ["-c", bind_config.as_posix()]

    print("Native Nextflow found: {}. Run from {}:\n".format(nextflow, REPO))
    print("  " + " ".join(shlex.quote(part) for part in command) + "\n")
    if args.dry_run:
        print("Dry run: nothing was started. A real run first copies data/rosmap.tar.gz to {} and writes {}."
              .format(rel(input_tar), rel(samplesheet)))
        return 0

    if args.profile == "docker":
        require_docker()
        for name in methods_of(args):
            require_built_image(name)
    elif not (shutil.which("apptainer") or shutil.which("singularity")):
        raise UserError("Cannot find apptainer. Install it, or use --profile docker.")

    if out_dir.exists():
        shutil.rmtree(str(out_dir))
    out_dir.mkdir(parents=True)
    input_tar.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(str(REPO / "data" / "rosmap.tar.gz"), str(input_tar))
    write(samplesheet, "dataset_name,tar_path\nrosmap,{}\n".format(input_tar.as_posix()))
    if args.profile == "apptainer":
        write(bind_config, "apptainer.runOptions = '--bind {0}:{0}'\n".format(work_dir.as_posix()))
    if args.stub:
        write(stub_script, render("stub_test.nf", {"method": method, "METHOD": method.upper()}))
    sys.stdout.flush()
    try:
        code = subprocess.call([nextflow] + command[1:], cwd=str(REPO))
    finally:
        if stub_script.exists():
            stub_script.unlink()

    def fetch(name, target):
        for folder, _, files in os.walk(str(outdir)):
            if name in files:
                shutil.copyfile(os.path.join(folder, name), str(target))
                return None
        return "not found"

    # With -stub, Nextflow itself fails if a declared output is missing: nothing is published to read.
    summary_ok = args.stub or summarise(methods_of(args), out_dir, fetch)
    if code == 0 and summary_ok:
        print("\nResult: PASS")
        return 0
    print("\nResult: FAIL (Nextflow exit code {})".format(code))
    print("Nextflow's message above names the failed process and its error. Work folders are under work/.")
    return 1


def test_in_docker(args):
    """No Nextflow installed, as on Windows: run Nextflow itself in a container.

    It starts task containers through the host's Docker daemon, so every path must mean the
    same thing inside the Nextflow container and on the daemon. /tmp/... is a daemon-side
    path on Linux, Mac and Docker Desktop on Windows.
    """
    method = args.method
    run_dir = "{}/{}".format(TEST_ROOT, method)
    repo = run_dir + "/repo"
    helper = "messi_add_method_{}".format(method)
    results = run_dir + "/results"
    out_dir = REPO / "results" / "add_method_test" / method
    script = "_stub_test.nf" if args.stub else "main.nf"

    command = nextflow_command(script, "docker", results, repo + "/samplesheet_local.csv", args)
    print("No native Nextflow: using the {} container. Inside it, in {}:\n".format(NEXTFLOW_IMAGE, repo))
    print("  " + " ".join(command) + "\n")
    if args.dry_run:
        print("Dry run: nothing was started.")
        return 0

    require_docker()
    for name in methods_of(args):
        require_built_image(name)
    print("Preparing the run folder {} on the Docker side".format(run_dir))
    docker_output("rm", "-f", helper)
    code, output = docker_output("run", "-d", "--name", helper, "-v", "{0}:{0}".format(TEST_ROOT),
                                 "--entrypoint", "", NEXTFLOW_IMAGE, "sleep", "86400")
    if code != 0:
        raise UserError("Could not start the helper container:\n" + output)
    try:
        docker_output("exec", helper, "sh", "-c", 'rm -rf "{0}" && mkdir -p "{1}" "{2}"'.format(run_dir, repo, results))
        sheet = "dataset_name,tar_path\nrosmap,{}/work/_inputs/rosmap.tar.gz\n".format(repo).encode()
        extra = {"samplesheet_local.csv": sheet}
        if args.stub:
            values = {"method": method, "METHOD": method.upper()}
            extra["_stub_test.nf"] = render("stub_test.nf", values).encode()
        code, output = docker_output("cp", "-", "{}:{}".format(helper, repo), stdin=tar_repo(extra))
        if code != 0:
            raise UserError("Could not copy the pipeline into Docker:\n" + output)

        sys.stdout.flush()
        done = docker("run", "--rm", "-v", "/var/run/docker.sock:/var/run/docker.sock",
                      "-v", "{0}:{0}".format(TEST_ROOT), "-w", repo, "-e", "NXF_ANSI_LOG=false",
                      NEXTFLOW_IMAGE, *command)

        # The Nextflow image has no find
        _, listing = docker_output("exec", helper, "ls", "-R", results)
        published = {}
        folder = results
        for line in listing.splitlines():
            if line.endswith(":"):
                folder = line[:-1]
            elif line.strip():
                published.setdefault(line.strip(), folder + "/" + line.strip())

        def fetch(name, target):
            if name not in published:
                return "not found"
            copied, message = docker_output("cp", "{}:{}".format(helper, published[name]), str(target))
            return None if copied == 0 else "could not copy it out: " + message.strip()

        if out_dir.exists():
            shutil.rmtree(str(out_dir))
        out_dir.mkdir(parents=True)
        # With -stub, Nextflow itself fails if a declared output is missing: nothing is published to read.
        summary_ok = args.stub or summarise(methods_of(args), out_dir, fetch)
    finally:
        docker_output("rm", "-f", helper)

    if done.returncode == 0 and summary_ok:
        print("\nResult: PASS")
        return 0
    print("\nResult: FAIL (Nextflow exit code {})".format(done.returncode))
    print("Nextflow's message above names the failed process and its error.")
    print("To look at the work folders, which stay until the next test run:")
    print('  docker run --rm -it -v {0}:{0} -w {1} {2} bash'.format(TEST_ROOT, repo, NEXTFLOW_IMAGE))
    return 1


def cmd_test(args):
    for name in methods_of(args):
        locate(name)
    if args.print_skip_flags:
        print(skip_flags(*methods_of(args)))
        return 0
    nextflow = native_nextflow()
    if nextflow:
        return test_native(args, nextflow)
    if args.profile != "docker":
        raise UserError("--profile {} needs Nextflow installed on this machine. Without it, only docker works."
                        .format(args.profile))
    return test_in_docker(args)


# ---------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------


def build_parser():
    parser = argparse.ArgumentParser(
        prog="add_method.py",
        description="Add a new method to the MESSI pipeline. With no arguments it asks one question at a time.",
        epilog="Also: 'add_method.py check NAME', 'check-image NAME [--image IMAGE]', "
               "'test NAME [--stub] [--profile docker|apptainer] [--dry-run]'. Guide: " + DOC,
    )
    parser.add_argument("--method", help="method name: lowercase letters, digits, underscores")
    parser.add_argument("--language", help="R or Python")
    parser.add_argument("--container",
                        help="an existing image (rgcca, eipy, or a full image name), or 'new' to generate "
                             "a Dockerfile (new:USER/NAME:TAG sets its image name)")
    parser.add_argument("--example", choices=EXAMPLES, help="generate the method with its functions filled in")
    parser.add_argument("--yes", action="store_true", help="no questions: needs --method and --language")
    parser.add_argument("--dry-run", action="store_true", help="show the plan, write nothing")
    return parser


def main(argv):
    if argv and argv[0] == "check":
        parser = argparse.ArgumentParser(prog="add_method.py check",
                                         description="Run the three functions on synthetic data. No Nextflow or containers.")
        parser.add_argument("method")
        return cmd_check(parser.parse_args(argv[1:]))
    if argv and argv[0] == "check-image":
        parser = argparse.ArgumentParser(prog="add_method.py check-image",
                                         description="Check that a container image qualifies for this method.")
        parser.add_argument("method")
        parser.add_argument("--image", help="image to check instead of the one declared for the method")
        return cmd_check_image(parser.parse_args(argv[1:]))
    if argv and argv[0] == "test":
        parser = argparse.ArgumentParser(prog="add_method.py test",
                                         description="Run only this method through Nextflow on rosmap. Uses the nextflow on "
                                                     "PATH if there is one, otherwise the Nextflow container.")
        parser.add_argument("method")
        parser.add_argument("--stub", action="store_true", help="use the stub: blocks with placeholder inputs")
        parser.add_argument("--folds", type=int, default=2, help="number of cross-validation folds (default 2)")
        parser.add_argument("--profile", choices=["docker", "apptainer"], default="docker",
                            help="container engine (default docker). apptainer needs Nextflow installed")
        parser.add_argument("--also", action="append", metavar="METHOD",
                            help="leave this method on as well, repeatable")
        parser.add_argument("--dry-run", action="store_true", help="print the exact command, start nothing")
        parser.add_argument("--print-skip-flags", action="store_true",
                            help="print the --skip_x flags that leave only this method on, and stop")
        return cmd_test(parser.parse_args(argv[1:]))
    return cmd_generate(build_parser().parse_args(argv))


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except UserError as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nStopped. If this happened at a question, nothing was written.", file=sys.stderr)
        sys.exit(130)
