import logging
import yaml
import os
import sys
import textwrap
import jinja2
import shutil
from pathlib import Path
from docopt import docopt


log = logging.getLogger(__name__)

class MethodCreate:
  """Creates relevant nextflow modules or subworkflows and their corresponding
  scripts that a method should inherit and have from template

  Args:
    method (str): Name of the method
    language (str): Language that the method was implemented in
    outdir (str): Path to local output directory
    docker_user (str): Username of the dockerhub to retreive image
    force_update (bool): Force to update/rewrite the contents of a modules/subworkflows
  """

  def __init__(
      self,
      method,
      language,
      outdir,
      docker_user=None,
      force_update=False
  ):

    # Setting convenient vars
    self.method = method
    self.language = language
    self.outdir = Path(outdir)
    self.docker_user = docker_user if docker_user is not None else "tonyliang19"
    self.force_update = force_update
    # Then have another param dict for jinja2 to use
    self.params_dict = {"method": method,
                        "language": language,
                        "outdir": outdir,
                        "docker_user": self.docker_user,
                        "force_update": force_update
                        }



  def init_method(self):
      """
      Creates the method relevant files
      """
      # Check if method exists
      self.check_method_exists()
      # Create files from templates using jinja
      self.render_template()
      # also modify the subworkflow language specific file
      self.modify_subworkflow_lang()
      return None
  
  def check_method_exists(self):
      """
      Check if the method already exists as a subworkflow
      """

      method = self.params_dict["method"]
      subworkflow_file = f"subworkflows/methods/{method}/main.nf"
      exists = os.path.isfile(subworkflow_file)
      # Another is flag option to see if wanting to force update
      force_update = self.params_dict["force_update"]
      if not exists:
          return
      if force_update:
          print("Force update contents from template, could be dangerous")
          return
      else:
        raise FileExistsError(f"Found the subworkflow for '{method}', please change a name for the method")
      # TODO: also checks if files already in the modules/<method>/...

  def modify_subworkflow_lang(self):
    """Modifies an existing file by adding a new line for a method after a specific line.

    Args:
        file_path (str): Path to the file to be modified
        method (str): Name of the method to add
    """
    # Convenient vars
    method = self.params_dict["method"]
    try:
      if self.params_dict["language"].lower() == 'r':
          file_to_modify = self.outdir / "subworkflows/cross_validation/r/main.nf"
          data_copy = "mae_copy"
      elif self.params_dict["language"].lower() == 'python':
          file_to_modify = self.outdir / "subworkflows/cross_validation/python/main.nf"
          data_copy = "mu_copy"
      else:
          raise NotImplementedError
      print(f"writing to '{file_to_modify}'")
    except Exception as e:
        log.error("Something went wrong: e")

    # Need to include few lines:
    # 1. include statement
    include_line = f'include {{ {method.upper()} }} from "${{subworkflowDir}}/methods/{method.lower()}"'
    # 2. Initialize and declare boolean to not skip method
    skip_method_line   = f"skip_{method.lower()} = false // boolean: true/false"
    # 3. Initialize results and store to var
    result_lines = f"""
    // {method.upper()}
    {method.lower()}_results = Channel.empty()
    if (!skip_{method.lower()}) {{
        {method.upper()} ( {data_copy} )
        {method.lower()}_results = {method.upper()}.out.csv_results
    }}
    """
    # 4. Declare output to mix
    output_line = f".mix( {method.lower()}_results )"
    # Put these together with their insertion point
    inserction_dict = {
      "// Methods to include": include_line, # For 1.
      "// Skip or trigger method to run": skip_method_line, # For 2.
      "// Instantiation of method subworkflows": result_lines, # For 3.,
      "// Then these are outputs of methods": output_line # For 4.

    }

    # Read the existing file
    with open(file_to_modify, 'r') as file:
        lines = file.readlines()
    # Insert new lines into the script
    for insertion_point, new_line in inserction_dict.items():
        index = next((i for i, line in enumerate(lines) if insertion_point in line), -1)
        existing_line = lines[index + 1]
        if existing_line.strip() in new_line.strip():
            # If already written, then skip tp avoid duplicates
            continue
        try:
           # Determine the indentation of the previous line
           previous_indent = len(lines[index]) - len(lines[index].lstrip())
           # Add the new line with the same indentation
           lines.insert(index + 1, ' ' * previous_indent + new_line.lstrip() + "\n")
        except Exception as e:
           print(f"Could not append to '{file_to_modify}' due to {e}")

    # Write back the modified content
    with open(file_to_modify, 'w') as file:
       file.writelines(lines)
    return None

  def render_template(self):
    """Runs jinja to create all relevant files for the method"""
    log.info(f"Creating relevant files for: '{self.method}'")

    # current_dir = os.path.dirname(os.path.abspath(__file__))

    # # Navigate to the parent directory (root)
    # root_dir = os.path.dirname(current_dir)
    # template_dir = os.path.join(root_dir, "method-template")
    # Run jinja2 for each file in the template folder
    template_dir = os.path.join(os.path.dirname(__file__), "method-template")
    env = jinja2.Environment(
      loader=jinja2.FileSystemLoader(searchpath=template_dir),
      keep_trailing_newline=True
    )

    # TODO: need to better handle this path using os
    object_attrs = self.params_dict
    method = object_attrs["method"]
    try:
      if object_attrs["language"].lower() == 'r':
        ext = "R"
      elif object_attrs["language"].lower() == 'python':
        ext = "py"
      object_attrs["ext"] = ext
    except Exception:
      raise NotImplementedError

    # Then glob the template files
    # POSIX might not work on windows
    template_files = list(Path(template_dir).glob("**/*"))
    template_files += list(Path(template_dir).glob("*"))
    # files to ignore
    ignore_strs = [".pyc", "__pycache__", ".pyo", ".pyd", ".DS_Store", ".egg", ".yaml"]
    # Then rename some templates to the one using method name
    resource_prefix = "resources/usr/bin"
    # TODO: this is very ugly now .....
    rename_files = {
      # The main workflow of the method
      "subworkflows/methods/method/main.nf": f"subworkflows/methods/{method}/main.nf",
      # And for each action in preprocess, train, predict, select_feature, and their resource script
      # PREPROCESS
      "modules/method/preprocess/main.nf" :     f"modules/{method}/preprocess/main.nf",
      "modules/method/train/main.nf" :          f"modules/{method}/train/main.nf",
      "modules/method/predict/main.nf" :        f"modules/{method}/predict/main.nf",
      "modules/method/select_feature/main.nf" : f"modules/{method}/select_feature/main.nf",
      # And the resources scripts
      f"modules/method/preprocess/{resource_prefix}/method_preprocess.{ext}":           f"modules/{method}/preprocess/{resource_prefix}/{method}_preprocess.{ext}",
      f"modules/method/train/{resource_prefix}/method_train.{ext}":                     f"modules/{method}/train/{resource_prefix}/{method}_train.{ext}",
      f"modules/method/predict/{resource_prefix}/method_predict.{ext}":                 f"modules/{method}/predict/{resource_prefix}/{method}_predict.{ext}",
      f"modules/method/select_feature/{resource_prefix}/method_select_feature.{ext}":   f"modules/{method}/select_feature/{resource_prefix}/{method}_select_feature.{ext}"
    }

    # Then loop through all template files
    for template_fn_path_obj in template_files:
        template_fn_path = str(template_fn_path_obj)
        if os.path.isdir(template_fn_path):
          continue
        # Given we have both scripts from R and Python, only populate the one matches language
        is_resource_script = template_fn_path.__contains__(resource_prefix)
        is_right_ext = template_fn_path.__contains__(ext)
        if is_resource_script and not is_right_ext:
          continue

        if any([s in template_fn_path for s in ignore_strs]):
          log.debug(f"Ignoring '{template_fn_path}' in jinja2 template creation")
          continue
        # Set up vars and directories
        template_fn = os.path.relpath(template_fn_path, template_dir)
        output_path = self.outdir / template_fn

        if template_fn in rename_files:
            output_path = self.outdir / rename_files[template_fn]
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
        # Then rest should just do this:
        try:
          log.debug(f"Rendering template file: '{template_fn}'")
          j_template = env.get_template(template_fn)
          rendered_output = j_template.render(object_attrs)
          # Write to the output file
          with open(output_path, "w") as fh:
            log.debug(f"Writing to output file: '{output_path}'")
            fh.write(rendered_output)
        # Copy the file directly instead of using Jinja
        except (AttributeError, UnicodeDecodeError) as e:
          log.debug(f"Copying file without Jinja: '{output_path}' - {e}")
          shutil.copy(template_fn_path, output_path)
        # Something else went wrong
        except Exception as e:
          print(f"Template could not be copied: '{template_fn_path}'")
          #log.error(f"Copying raw file as error rendering with Jinja: '{output_path}' - {e}")
          #shutil.copy(template_fn_path, output_path)
        template_stat = os.stat(template_fn_path)
        os.chmod(output_path, template_stat.st_mode)
    # DONE the for loop
    return None
